local M = {}

--- Enumeration describing the types of events watchers will emit.
M.FileChangeType = vim.tbl_add_reverse_lookup({
  Created = 1,
  Changed = 2,
  Deleted = 3,
})

---@private
--- Joins filepath elements by static '/' separator
---
---@param ... (string) The path elements.
local function filepath_join(...)
  return table.concat({ ... }, '/')
end

---@private
--- Stops and closes a libuv |uv_fs_event_t| or |uv_fs_poll_t| handle
---
---@param handle (uv_fs_event_t|uv_fs_poll_t) The handle to stop
local function stop(handle)
  local _, stop_err = handle:stop()
  assert(not stop_err, stop_err)
  local is_closing, close_err = handle:is_closing()
  assert(not close_err, close_err)
  if not is_closing then
    handle:close()
  end
end

--- Initializes and starts a |uv_fs_event_t|
---
---@param path (string) The path to watch
---@param opts (table|nil) Additional options
---     - uvflags (table|nil)
---                Same flags as accepted by |uv.fs_event_start()|
---@param callback (function) The function called when new events
---@returns (function) A function to stop the watch
function M.watch(path, opts, callback)
  vim.validate({
    path = { path, 'string', false },
    opts = { opts, 'table', true },
    callback = { callback, 'function', false },
  })

  path = vim.fs.normalize(path)
  local uvflags = opts and opts.uvflags or {}
  local handle, new_err = vim.loop.new_fs_event()
  assert(not new_err, new_err)
  local _, start_err = handle:start(path, uvflags, function(err, filename, events)
    assert(not err, err)
    local fullpath = path
    if filename then
      filename = filename:gsub('\\', '/')
      fullpath = filepath_join(fullpath, filename)
    end
    local change_type = events.change and M.FileChangeType.Changed or 0
    if events.rename then
      local _, staterr, staterrname = vim.loop.fs_stat(fullpath)
      if staterrname == 'ENOENT' then
        change_type = M.FileChangeType.Deleted
      else
        assert(not staterr, staterr)
        change_type = M.FileChangeType.Created
      end
    end
    callback(fullpath, change_type)
  end)
  assert(not start_err, start_err)
  return function()
    stop(handle)
  end
end

local default_poll_interval_ms = 2000

---@private
--- Implementation for poll, hiding internally-used parameters.
---
---@param watches (table|nil) A tree structure to maintain state for recursive watches.
---     - handle (uv_fs_poll_t)
---               The libuv handle
---     - cancel (function)
---               A function that cancels the handle and all children's handles
---     - is_dir (boolean)
---               Indicates whether the path is a directory (and the poll should
---               be invoked recursively)
---     - children (table|nil)
---               A mapping of directory entry name to its recursive watches
--      - started (boolean|nil)
--                Whether or not the watcher has first been initialized. Used
--                to prevent a flood of Created events on startup.
local function poll_internal(path, opts, callback, watches)
  path = vim.fs.normalize(path)
  local interval = opts and opts.interval or default_poll_interval_ms
  watches = watches or {
    is_dir = true,
  }

  if not watches.handle then
    local poll, new_err = vim.loop.new_fs_poll()
    assert(not new_err, new_err)
    watches.handle = poll
    local _, start_err = poll:start(
      path,
      interval,
      vim.schedule_wrap(function(err)
        if err == 'ENOENT' then
          return
        end
        assert(not err, err)
        poll_internal(path, opts, callback, watches)
        callback(path, M.FileChangeType.Changed)
      end)
    )
    assert(not start_err, start_err)
    if watches.started then
      callback(path, M.FileChangeType.Created)
    end
  end

  watches.cancel = function()
    if watches.children then
      for _, w in pairs(watches.children) do
        w.cancel()
      end
    end
    stop(watches.handle)
  end

  if watches.is_dir then
    watches.children = watches.children or {}
    local exists = {}
    for name, ftype in vim.fs.dir(path) do
      exists[name] = true
      if not watches.children[name] then
        watches.children[name] = {
          is_dir = ftype == 'directory',
          started = watches.started,
        }
        poll_internal(filepath_join(path, name), opts, callback, watches.children[name])
      end
    end

    local newchildren = {}
    for name, watch in pairs(watches.children) do
      if exists[name] then
        newchildren[name] = watch
      else
        watch.cancel()
        watches.children[name] = nil
        callback(path .. '/' .. name, M.FileChangeType.Deleted)
      end
    end
    watches.children = newchildren
  end

  watches.started = true

  return watches.cancel
end

--- Initializes and starts a |uv_fs_poll_t| recursively watching every file underneath the
--- directory at path.
---
---@param path (string) The path to watch. Must refer to a directory.
---@param opts (table|nil) Additional options
---     - interval (number|nil)
---                Polling interval in ms as passed to |uv.fs_poll_start()|. Defaults to 2000.
---@param callback (function) The function called when new events
---@returns (function) A function to stop the watch.
function M.poll(path, opts, callback)
  vim.validate({
    path = { path, 'string', false },
    opts = { opts, 'table', true },
    callback = { callback, 'function', false },
  })
  return poll_internal(path, opts, callback, nil)
end

return M
