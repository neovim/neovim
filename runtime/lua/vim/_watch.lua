local uv = vim.uv

local M = {}

--- @enum vim._watch.FileChangeType
--- Types of events watchers will emit.
M.FileChangeType = {
  Created = 1,
  Changed = 2,
  Deleted = 3,
}

--- @class vim._watch.Opts
---
--- @field debounce? integer ms
---
--- An |lpeg| pattern. Only changes to files whose full paths match the pattern
--- will be reported. Only matches against non-directoriess, all directories will
--- be watched for new potentially-matching files. exclude_pattern can be used to
--- filter out directories. When nil, matches any file name.
--- @field include_pattern? vim.lpeg.Pattern
---
--- An |lpeg| pattern. Only changes to files and directories whose full path does
--- not match the pattern will be reported. Matches against both files and
--- directories. When nil, matches nothing.
--- @field exclude_pattern? vim.lpeg.Pattern

--- @alias vim._watch.Callback fun(path: string, change_type: vim._watch.FileChangeType)

--- @class vim._watch.watch.Opts : vim._watch.Opts
--- @field uvflags? uv.fs_event_start.flags

--- @param path string
--- @param opts? vim._watch.Opts
local function skip(path, opts)
  if not opts then
    return false
  end

  if opts.include_pattern and opts.include_pattern:match(path) == nil then
    return true
  end

  if opts.exclude_pattern and opts.exclude_pattern:match(path) ~= nil then
    return true
  end

  return false
end

--- Initializes and starts a |uv_fs_event_t|
---
--- @param path string The path to watch
--- @param opts vim._watch.watch.Opts? Additional options:
---      - uvflags (table|nil)
---                 Same flags as accepted by |uv.fs_event_start()|
--- @param callback vim._watch.Callback Callback for new events
--- @return fun() cancel Stops the watcher
function M.watch(path, opts, callback)
  vim.validate({
    path = { path, 'string', false },
    opts = { opts, 'table', true },
    callback = { callback, 'function', false },
  })

  opts = opts or {}

  path = vim.fs.normalize(path)
  local uvflags = opts and opts.uvflags or {}
  local handle = assert(uv.new_fs_event())

  local _, start_err = handle:start(path, uvflags, function(err, filename, events)
    assert(not err, err)
    local fullpath = path
    if filename then
      fullpath = vim.fs.normalize(vim.fs.joinpath(fullpath, filename))
    end

    if skip(fullpath, opts) then
      return
    end

    --- @type vim._watch.FileChangeType
    local change_type
    if events.rename then
      local _, staterr, staterrname = uv.fs_stat(fullpath)
      if staterrname == 'ENOENT' then
        change_type = M.FileChangeType.Deleted
      else
        assert(not staterr, staterr)
        change_type = M.FileChangeType.Created
      end
    elseif events.change then
      change_type = M.FileChangeType.Changed
    end
    callback(fullpath, change_type)
  end)

  assert(not start_err, start_err)

  return function()
    local _, stop_err = handle:stop()
    assert(not stop_err, stop_err)
    local is_closing, close_err = handle:is_closing()
    assert(not close_err, close_err)
    if not is_closing then
      handle:close()
    end
  end
end

--- Initializes and starts a |uv_fs_event_t| recursively watching every directory underneath the
--- directory at path.
---
--- @param path string The path to watch. Must refer to a directory.
--- @param opts vim._watch.Opts? Additional options
--- @param callback vim._watch.Callback Callback for new events
--- @return fun() cancel Stops the watcher
function M.watchdirs(path, opts, callback)
  vim.validate({
    path = { path, 'string', false },
    opts = { opts, 'table', true },
    callback = { callback, 'function', false },
  })

  opts = opts or {}
  local debounce = opts.debounce or 500

  ---@type table<string, uv.uv_fs_event_t> handle by fullpath
  local handles = {}

  local timer = assert(uv.new_timer())

  --- Map of file path to boolean indicating if the file has been changed
  --- at some point within the debounce cycle.
  --- @type table<string, boolean>
  local filechanges = {}

  local process_changes --- @type fun()

  --- @param filepath string
  --- @return uv.fs_event_start.callback
  local function create_on_change(filepath)
    return function(err, filename, events)
      assert(not err, err)
      local fullpath = vim.fs.joinpath(filepath, filename)
      if skip(fullpath, opts) then
        return
      end

      if not filechanges[fullpath] then
        filechanges[fullpath] = events.change or false
      end
      timer:start(debounce, 0, process_changes)
    end
  end

  process_changes = function()
    -- Since the callback is debounced it may have also been deleted later on
    -- so we always need to check the existence of the file:
    --   stat succeeds, changed=true  -> Changed
    --   stat succeeds, changed=false -> Created
    --   stat fails                   -> Removed
    for fullpath, changed in pairs(filechanges) do
      uv.fs_stat(fullpath, function(_, stat)
        ---@type vim._watch.FileChangeType
        local change_type
        if stat then
          change_type = changed and M.FileChangeType.Changed or M.FileChangeType.Created
          if stat.type == 'directory' then
            local handle = handles[fullpath]
            if not handle then
              handle = assert(uv.new_fs_event())
              handles[fullpath] = handle
              handle:start(fullpath, {}, create_on_change(fullpath))
            end
          end
        else
          change_type = M.FileChangeType.Deleted
          local handle = handles[fullpath]
          if handle then
            if not handle:is_closing() then
              handle:close()
            end
            handles[fullpath] = nil
          end
        end
        callback(fullpath, change_type)
      end)
    end
    filechanges = {}
  end

  local root_handle = assert(uv.new_fs_event())
  handles[path] = root_handle
  root_handle:start(path, {}, create_on_change(path))

  --- "640K ought to be enough for anyone"
  --- Who has folders this deep?
  local max_depth = 100

  for name, type in vim.fs.dir(path, { depth = max_depth }) do
    local filepath = vim.fs.joinpath(path, name)
    if type == 'directory' and not skip(filepath, opts) then
      local handle = assert(uv.new_fs_event())
      handles[filepath] = handle
      handle:start(filepath, {}, create_on_change(filepath))
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

--- @param data string
--- @param opts vim._watch.Opts?
--- @param callback vim._watch.Callback
local function fswatch_output_handler(data, opts, callback)
  local d = vim.split(data, '%s+')

  -- only consider the last reported event
  local fullpath, event = d[1], d[#d]

  if skip(fullpath, opts) then
    return
  end

  --- @type integer
  local change_type

  if event == 'Created' then
    change_type = M.FileChangeType.Created
  elseif event == 'Removed' then
    change_type = M.FileChangeType.Deleted
  elseif event == 'Updated' then
    change_type = M.FileChangeType.Changed
  elseif event == 'Renamed' then
    local _, staterr, staterrname = uv.fs_stat(fullpath)
    if staterrname == 'ENOENT' then
      change_type = M.FileChangeType.Deleted
    else
      assert(not staterr, staterr)
      change_type = M.FileChangeType.Created
    end
  end

  if change_type then
    callback(fullpath, change_type)
  end
end

--- @param path string The path to watch. Must refer to a directory.
--- @param opts vim._watch.Opts?
--- @param callback vim._watch.Callback Callback for new events
--- @return fun() cancel Stops the watcher
function M.fswatch(path, opts, callback)
  -- debounce isn't the same as latency but close enough
  local latency = 0.5 -- seconds
  if opts and opts.debounce then
    latency = opts.debounce / 1000
  end

  local obj = vim.system({
    'fswatch',
    '--event=Created',
    '--event=Removed',
    '--event=Updated',
    '--event=Renamed',
    '--event-flags',
    '--recursive',
    '--latency=' .. tostring(latency),
    '--exclude',
    '/.git/',
    path,
  }, {
    stderr = function(err, data)
      if err then
        error(err)
      end

      if data and #vim.trim(data) > 0 then
        vim.schedule(function()
          vim.notify('fswatch: ' .. data, vim.log.levels.ERROR)
        end)
      end
    end,
    stdout = function(err, data)
      if err then
        error(err)
      end

      for line in vim.gsplit(data or '', '\n', { plain = true, trimempty = true }) do
        fswatch_output_handler(line, opts, callback)
      end
    end,
  })

  return function()
    obj:kill(2)
  end
end

return M
