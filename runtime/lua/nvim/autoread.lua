--- Provides 'autoread' via OS filewatchers: watches 'autoread' buffer files for external changes
--- using vim._watch. Complements the existing FocusGained/:checktime approach.

local uv = vim.uv
local watch = vim._watch
local nvim_on = require('vim._core.util').nvim_on

local M = {}

local debounce_ms = 100
--- @type table<integer, fun()> bufnr -> cancel function
local file_watchers = {}

--- @type table<integer, { path: string, dir: string }> bufnr -> buffer watcher state
local buffers = {}
--- @type table<string, { cancel: fun()?, bufs: table<integer, true>, mode: 'file'|'dir' }> dir -> watcher state
local dirs = {}

--- @type table<integer, uv.uv_timer_t> bufnr -> debounce timer
local timers = {}
--- @type table<integer, true> bufnr -> true. Tracks pending autoreads (debounce window, or :checktime in flight),
--- so we can surface activity via the 'busy' flag.
local pending = {}
--- @type table<integer, true> bufnr -> true. Tracks which `pending` buffers have set 'busy'.
local pending_busy = {}

--- @type fun(bufnr: integer)
local ensure_watcher

--- @private
--- Test-only: override the debounce window so tests can run faster.
--- @param ms integer
function M._set_debounce(ms)
  debounce_ms = ms
end

--- @private
--- @param bufnr integer
--- @return boolean
function M._is_watching(bufnr)
  return file_watchers[bufnr] ~= nil or buffers[bufnr] ~= nil
end

--- @private
--- @param bufnr integer
--- @return 'file'|'dir'|nil
function M._watching_mode(bufnr)
  if file_watchers[bufnr] ~= nil then
    return 'file'
  end
  local buf = buffers[bufnr]
  local entry = buf and dirs[buf.dir]
  return entry and entry.mode or nil
end

--- Sets the 'busy' option on a `pending` buffer. Idempotent: if `pending` and `pending_busy`
--- already agree, it's a no-op. Must run on main thread.
---
--- @param bufnr integer
local function sync_busy(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    pending_busy[bufnr] = nil
    return
  end
  local want = pending[bufnr] ~= nil
  local have = pending_busy[bufnr] ~= nil
  if want == have then
    return
  end
  vim.bo[bufnr].busy = math.max(0, vim.bo[bufnr].busy + (want and 1 or -1))
  pending_busy[bufnr] = want or nil
end

--- Sends `pending` state for `bufnr`.
---
--- @param bufnr integer
--- @param is_pending boolean
local function set_pending(bufnr, is_pending)
  pending[bufnr] = is_pending or nil
  vim.schedule(function()
    sync_busy(bufnr)
  end)
end

--- Returns the effective 'autoread' value for a buffer.
--- 'autoread' is global-local: vim.bo[bufnr].autoread is nil when not set locally,
--- so we must fall back to the global value.
--- @param bufnr integer
--- @return boolean
local function buf_autoread(bufnr)
  local local_val = vim.bo[bufnr].autoread
  if local_val ~= nil then
    return local_val
  end
  return vim.go.autoread
end

--- Returns true if the buffer should be watched.
--- @param bufnr integer
--- @return boolean
local function should_watch(bufnr)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return false
  end
  -- Skip special buffers (terminal, help, quickfix, etc.)
  if vim.bo[bufnr].buftype ~= '' then
    return false
  end
  -- Must have a file name that exists on disk
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' or not uv.fs_stat(name) then
    return false
  end
  if not buf_autoread(bufnr) then
    return false
  end
  return true
end

--- Returns true if autoread should share one watcher between buffers in the same directory.
--- @return boolean
local function use_dir_watchers()
  local value = vim.g.autoread_watch_dir
  return value ~= false and value ~= 0
end

--- Returns the number of buffers in a directory needed before sharing one directory watcher.
--- @return integer
local function dir_watch_threshold()
  local threshold = tonumber(vim.g.autoread_watch_dir_threshold) or 3
  return math.max(2, math.floor(threshold))
end

--- Handles one file change event for a buffer.
---
--- @param bufnr integer
--- @param change_type vim._watch.FileChangeType
local function on_file_change(bufnr, change_type)
  local timer = timers[bufnr]
  if not timer then
    return
  end

  -- Set the 'busy' buffer option for the duration of the pending cycle. This is a small, "best
  -- effort" UX hint, not intended to be noticeable except when filewatcher activity is "noisy".
  set_pending(bufnr, true)
  -- Debounce: restart the same timer on each event, so only the last
  -- event in a rapid series (e.g. truncate + write) triggers checktime.
  timer:start(debounce_ms, 0, function()
    vim.schedule(function()
      sync_busy(bufnr)
      if not vim.api.nvim_buf_is_loaded(bufnr) or not buf_autoread(bufnr) then
        set_pending(bufnr, false)
        return
      end

      -- :checktime may throw if file was deleted (E211), or if reload triggers a buggy autocmd.
      local ok, err = pcall(vim.cmd.checktime, bufnr) ---@type any, any
      local file_missing = tostring(err):find('E211:', 1, true)

      set_pending(bufnr, false)
      -- Update the watcher if it's now stale: "rename" events (watcher pointing to old inode), or
      -- file deleted between event-and-:checktime.
      if change_type ~= watch.FileChangeType.Changed or file_missing then
        ensure_watcher(bufnr)
      end
      if not ok and not file_missing then
        vim.api.nvim_echo({
          { ('autoread: :checktime failed for buffer %d: %s'):format(bufnr, err) },
        }, true, { err = true })
      end
    end)
  end)
end

--- Starts one per-file watcher for a buffer.
---
--- @param bufnr integer
--- @param path string
local function start_file_watcher(bufnr, path)
  file_watchers[bufnr] = watch.watch(path, {}, function(_, change_type)
    on_file_change(bufnr, change_type)
  end)
end

--- Starts one directory watcher shared by all buffers in `entry`.
---
--- @param dir string
--- @param entry { cancel: fun()?, bufs: table<integer, true>, mode: 'file'|'dir' }
local function start_dir_watcher(dir, entry)
  if entry.cancel then
    entry.cancel()
  end

  entry.cancel = watch.watch(dir, {}, function(fullpath, change_type)
    fullpath = vim.fs.normalize(fullpath)
    for watched_bufnr in pairs(entry.bufs) do
      local buf = buffers[watched_bufnr]
      if buf and (buf.path == fullpath or fullpath == dir) then
        on_file_change(watched_bufnr, change_type)
      end
    end
  end)
  entry.mode = 'dir'
end

--- Stops a directory watcher when it is no longer needed.
---
--- @param dir string
local function maybe_stop_dir(dir)
  local entry = dirs[dir]
  if not entry or next(entry.bufs) ~= nil then
    return
  end

  if entry.cancel then
    entry.cancel()
  end
  dirs[dir] = nil
end

--- Stops and cleans up the watcher for a buffer.
--- @param bufnr integer
local function stop_watcher(bufnr)
  set_pending(bufnr, false)

  local cancel = file_watchers[bufnr]
  if cancel then
    cancel()
    file_watchers[bufnr] = nil
  end

  local buf = buffers[bufnr]
  if buf then
    local entry = dirs[buf.dir]
    if entry then
      entry.bufs[bufnr] = nil
      maybe_stop_dir(buf.dir)
    end
    buffers[bufnr] = nil
  end

  local timer = timers[bufnr]
  if timer then
    timer:stop()
    timer:close()
    timers[bufnr] = nil
  end
end

--- Ensures the buffer has an active file watcher if appropriate, or stops
--- an existing one if the buffer should no longer be watched.
--- @param bufnr integer
ensure_watcher = function(bufnr)
  stop_watcher(bufnr)

  if not should_watch(bufnr) then
    return
  end

  local path = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
  local dir = vim.fs.dirname(path)

  buffers[bufnr] = {
    path = path,
    dir = dir,
  }

  local entry = dirs[dir]
  if not entry then
    entry = {
      cancel = nil,
      bufs = {},
      mode = 'file',
    }
    dirs[dir] = entry
  end

  entry.bufs[bufnr] = true

  local timer = assert(uv.new_timer())
  timers[bufnr] = timer

  if use_dir_watchers() and entry.mode == 'dir' then
    return
  elseif use_dir_watchers() and vim.tbl_count(entry.bufs) >= dir_watch_threshold() then
    for watched_bufnr in pairs(entry.bufs) do
      local cancel = file_watchers[watched_bufnr]
      if cancel then
        cancel()
        file_watchers[watched_bufnr] = nil
      end
    end
    start_dir_watcher(dir, entry)
  else
    start_file_watcher(bufnr, path)
  end
end

function M.enable()
  local group = vim.api.nvim_create_augroup('nvim.autoread', { clear = true })

  -- (Re)start watcher when a file is loaded or written.
  nvim_on({ 'BufReadPost', 'BufWritePost' }, group, function(args)
    ensure_watcher(args.buf)
  end)

  -- Stop watcher when buffer is unloaded or wiped out.
  nvim_on({ 'BufUnload', 'BufWipeout' }, group, function(args)
    stop_watcher(args.buf)
  end)

  -- Clean up all watchers on exit to avoid dangling handles in the event loop.
  nvim_on('VimLeavePre', group, function()
    --- @type integer[]
    local watched_buffers = vim.tbl_keys(buffers)
    for _, bufnr in ipairs(watched_buffers) do
      stop_watcher(bufnr)
    end
  end)

  -- React to 'autoread' option changes.
  nvim_on('OptionSet', group, { pattern = 'autoread' }, function()
    if vim.v.option_type == 'global' then
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        ensure_watcher(bufnr)
      end
    else
      ensure_watcher(vim.api.nvim_get_current_buf())
    end
  end)

  -- Attach to buffers that were already loaded before enable() ran.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    ensure_watcher(bufnr)
  end
end

return M
