--- Watches buffer files for external changes using vim._watch.
--- When 'autoread' is set, external changes are detected in real-time
--- instead of only on FocusGained/:checktime.

local uv = vim.uv

local group = vim.api.nvim_create_augroup('nvim.autoread', { clear = true })

--- @type table<integer, fun()> bufnr -> cancel function
local watchers = {}

--- @type table<integer, uv.uv_timer_t> bufnr -> debounce timer
local timers = {}

local DEBOUNCE_MS = 100

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

--- Stops and cleans up the watcher for a buffer.
--- @param bufnr integer
local function stop_watcher(bufnr)
  local cancel = watchers[bufnr]
  if cancel then
    cancel()
    watchers[bufnr] = nil
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
local function ensure_watcher(bufnr)
  stop_watcher(bufnr)

  if not should_watch(bufnr) then
    return
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  local timer = assert(uv.new_timer())
  timers[bufnr] = timer

  local cancel = vim._watch.watch(name, {}, function(_, change_type)
    -- Debounce: restart the same timer on each event, so only the last
    -- event in a rapid series (e.g. truncate + write) triggers checktime.
    timer:start(DEBOUNCE_MS, 0, function()
      vim.schedule(function()
        if not vim.api.nvim_buf_is_loaded(bufnr) or not buf_autoread(bufnr) then
          return
        end
        vim.cmd.checktime(bufnr)
        -- On rename events (e.g. atomic save by another editor), the watcher
        -- is now stale (watching the old inode). Re-establish it.
        if change_type ~= vim._watch.FileChangeType.Changed then
          ensure_watcher(bufnr)
        end
      end)
    end)
  end)

  watchers[bufnr] = cancel
end

-- (Re)start watcher when a file is loaded or written.
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
  group = group,
  callback = function(args)
    ensure_watcher(args.buf)
  end,
})

-- Stop watcher when buffer is unloaded or wiped out.
vim.api.nvim_create_autocmd({ 'BufUnload', 'BufWipeout' }, {
  group = group,
  callback = function(args)
    stop_watcher(args.buf)
  end,
})

-- Clean up all watchers on exit to avoid dangling handles in the event loop.
vim.api.nvim_create_autocmd('VimLeavePre', {
  group = group,
  callback = function()
    for bufnr in pairs(watchers) do
      stop_watcher(bufnr)
    end
  end,
})

-- React to 'autoread' option changes.
vim.api.nvim_create_autocmd('OptionSet', {
  group = group,
  pattern = 'autoread',
  callback = function()
    if vim.v.option_type == 'global' then
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        ensure_watcher(bufnr)
      end
    else
      ensure_watcher(vim.api.nvim_get_current_buf())
    end
  end,
})
