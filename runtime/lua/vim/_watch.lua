local M = {}
local uv = vim.uv

---@enum vim._watch.FileChangeType
local FileChangeType = {
  Created = 1,
  Changed = 2,
  Deleted = 3,
}

--- Enumeration describing the types of events watchers will emit.
M.FileChangeType = vim.tbl_add_reverse_lookup(FileChangeType)

--- Joins filepath elements by static '/' separator
---
---@param ... (string) The path elements.
---@return string
local function filepath_join(...)
  return table.concat({ ... }, '/')
end

--- Stops and closes a libuv |uv_fs_event_t| or |uv_fs_poll_t| handle
---
---@param handle (uv.uv_fs_event_t|uv.uv_fs_poll_t) The handle to stop
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
---@return (function) Stops the watcher
function M.watch(path, opts, callback)
  vim.validate({
    path = { path, 'string', false },
    opts = { opts, 'table', true },
    callback = { callback, 'function', false },
  })

  path = vim.fs.normalize(path)
  local uvflags = opts and opts.uvflags or {}
  local handle, new_err = vim.uv.new_fs_event()
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
      local _, staterr, staterrname = vim.uv.fs_stat(fullpath)
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

--- @class watch.PollOpts
--- @field debounce? integer
--- @field include_pattern? vim.lpeg.Pattern
--- @field exclude_pattern? vim.lpeg.Pattern

---@param path string
---@param opts watch.PollOpts
---@param callback function Called on new events
---@return function cancel stops the watcher
local function recurse_watch(path, opts, callback)
  opts = opts or {}
  local debounce = opts.debounce or 500
  local uvflags = {}
  ---@type table<string, uv.uv_fs_event_t> handle by fullpath
  local handles = {}

  local timer = assert(uv.new_timer())

  ---@type table[]
  local changesets = {}

  local function is_included(filepath)
    return opts.include_pattern and opts.include_pattern:match(filepath)
  end
  local function is_excluded(filepath)
    return opts.exclude_pattern and opts.exclude_pattern:match(filepath)
  end

  local process_changes = function()
    assert(false, "Replaced later. I'm only here as forward reference")
  end

  local function create_on_change(filepath)
    return function(err, filename, events)
      assert(not err, err)
      local fullpath = vim.fs.joinpath(filepath, filename)
      if is_included(fullpath) and not is_excluded(filepath) then
        table.insert(changesets, {
          fullpath = fullpath,
          events = events,
        })
        timer:start(debounce, 0, process_changes)
      end
    end
  end

  process_changes = function()
    ---@type table<string, table[]>
    local filechanges = vim.defaulttable()
    for i, change in ipairs(changesets) do
      changesets[i] = nil
      if is_included(change.fullpath) and not is_excluded(change.fullpath) then
        table.insert(filechanges[change.fullpath], change.events)
      end
    end
    for fullpath, events_list in pairs(filechanges) do
      local stat = uv.fs_stat(fullpath)
      ---@type vim._watch.FileChangeType
      local change_type
      if stat then
        change_type = FileChangeType.Created
        for _, event in ipairs(events_list) do
          if event.change then
            change_type = FileChangeType.Changed
          end
        end
        if stat.type == 'directory' then
          local handle = handles[fullpath]
          if not handle then
            handle = assert(uv.new_fs_event())
            handles[fullpath] = handle
            handle:start(fullpath, uvflags, create_on_change(fullpath))
          end
        end
      else
        local handle = handles[fullpath]
        if handle then
          if not handle:is_closing() then
            handle:close()
          end
          handles[fullpath] = nil
        end
        change_type = FileChangeType.Deleted
      end
      callback(fullpath, change_type)
    end
  end
  local root_handle = assert(uv.new_fs_event())
  handles[path] = root_handle
  root_handle:start(path, uvflags, create_on_change(path))

  --- "640K ought to be enough for anyone"
  --- Who has folders this deep?
  local max_depth = 100

  for name, type in vim.fs.dir(path, { depth = max_depth }) do
    local filepath = vim.fs.joinpath(path, name)
    if type == 'directory' and not is_excluded(filepath) then
      local handle = assert(uv.new_fs_event())
      handles[filepath] = handle
      handle:start(filepath, uvflags, create_on_change(filepath))
    end
  end
  local function cancel()
    for fullpath, handle in pairs(handles) do
      if not handle:is_closing() then
        handle:close()
      end
      handles[fullpath] = nil
    end
    timer:stop()
    timer:close()
  end
  return cancel
end

--- Initializes and starts a |uv_fs_poll_t| recursively watching every file underneath the
--- directory at path.
---
---@param path (string) The path to watch. Must refer to a directory.
---@param opts (table|nil) Additional options
---     - debounce (number|nil)
---                Time events are debounced in ms. Defaults to 500
---     - include_pattern (LPeg pattern|nil)
---                An |lpeg| pattern. Only changes to files whose full paths match the pattern
---                will be reported. Only matches against non-directoriess, all directories will
---                be watched for new potentially-matching files. exclude_pattern can be used to
---                filter out directories. When nil, matches any file name.
---     - exclude_pattern (LPeg pattern|nil)
---                An |lpeg| pattern. Only changes to files and directories whose full path does
---                not match the pattern will be reported. Matches against both files and
---                directories. When nil, matches nothing.
---@param callback (function) The function called when new events
---@return function Stops the watcher
function M.poll(path, opts, callback)
  vim.validate({
    path = { path, 'string', false },
    opts = { opts, 'table', true },
    callback = { callback, 'function', false },
  })
  return recurse_watch(path, opts, callback)
end

return M
