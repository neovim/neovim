local uv = vim.uv

--- Can this directory contain matching paths? Keep ancestors so that matching directories
--- created later can still be discovered. Every nonempty root ends in '/', so '/src/'
--- cannot cover '/src2/'.
--- @param path string
--- @param filter vim._watch.CompiledFilter
--- @return boolean
local function matches_dir(path, filter)
  local dir = path:gsub('/$', '') .. '/'
  for _, root in ipairs(filter.roots) do
    if vim.startswith(dir, root) or vim.startswith(root, dir) then
      return true
    end
  end
  return false
end

--- @class (private) vim._watch.WatchDirs
--- @field private opts vim._watch.BackendOpts
--- @field private callback vim._watch.Callback
--- @field private handles table<string, uv.uv_fs_event_t> Handles by full path.
--- @field private timer uv.uv_timer_t
--- @field private cancelled boolean
--- @field private filechanges table<string, boolean> Whether each path changed during the debounce cycle.
local WatchDirs = {}
WatchDirs.__index = WatchDirs

--- @param opts vim._watch.BackendOpts
--- @param callback vim._watch.Callback
--- @return vim._watch.WatchDirs
function WatchDirs.new(opts, callback)
  return setmetatable({
    opts = opts,
    callback = callback,
    handles = {},
    timer = assert(uv.new_timer()),
    cancelled = false,
    filechanges = {},
  }, WatchDirs)
end

--- @private
--- Decides if `path` should be skipped.
--- @param path string
--- @param directory? boolean Check whether the directory can contain matching paths.
--- @return boolean
function WatchDirs:skip(path, directory)
  if directory then
    if not matches_dir(path, self.opts.include) then
      return true
    end
  elseif self.opts.include.pattern:match(path) == nil then
    return true
  end

  return self.opts.exclude ~= nil and self.opts.exclude.pattern:match(path) ~= nil
end

--- @private
--- @param path string
--- @return string? err
--- @return string? errname
function WatchDirs:add_watch(path)
  if self.handles[path] then
    return
  end

  local handle = assert(uv.new_fs_event())
  self.handles[path] = handle
  local _, start_err, errname = handle:start(path, {}, function(err, filename, events)
    self:on_change(path, err, filename, events)
  end)
  if start_err then
    handle:close()
    self.handles[path] = nil
  end
  return start_err, errname
end

--- @private
--- @param path string
function WatchDirs:remove_watch(path)
  local handle = self.handles[path]
  if handle then
    if not handle:is_closing() then
      handle:close()
    end
    self.handles[path] = nil
  end
end

--- @private
--- @param path string
--- @param err string?
--- @param filename string
--- @param events {change?: boolean, rename?: boolean}
function WatchDirs:on_change(path, err, filename, events)
  if self.cancelled then
    return
  end
  if err then
    return self.opts.on_error(err)
  end

  local fullpath = vim.fs.joinpath(path, filename)
  if self:skip(fullpath) then
    -- An unmatched directory can contain matching descendants. Track its creation/deletion
    -- even when no event for the directory itself will be reported.
    if
      self:skip(fullpath, true)
      or not events.rename
      or (not self.handles[fullpath] and (uv.fs_stat(fullpath) or {}).type ~= 'directory')
    then
      return
    end
  end

  if not self.filechanges[fullpath] then
    self.filechanges[fullpath] = events.change or false
  end

  self.timer:start(self.opts.debounce or 500, 0, function()
    -- Since the callback is debounced it may have also been deleted later on
    -- so we always need to check the existence of the file:
    --   stat succeeds, changed=true  -> Changed
    --   stat succeeds, changed=false -> Created
    --   stat fails                   -> Removed
    for changed_path, changed in pairs(self.filechanges) do
      uv.fs_stat(changed_path, function(_, stat)
        self:process_change(changed_path, changed, stat)
      end)
    end
    self.filechanges = {}
  end)
end

--- @private
--- @param fullpath string
--- @param changed boolean
--- @param stat uv.fs_stat.result?
function WatchDirs:process_change(fullpath, changed, stat)
  if self.cancelled then
    return
  end

  local FileChangeType = vim._watch.FileChangeType
  --- @type vim._watch.FileChangeType
  local change_type
  if stat then
    change_type = changed and FileChangeType.Changed or FileChangeType.Created
    if stat.type == 'directory' then
      local err, errname = self:add_watch(fullpath)
      -- The directory may have disappeared since fs_stat().
      if err and errname ~= 'ENOENT' then
        self.opts.on_error(err)
      end
    end
  else
    change_type = FileChangeType.Deleted
    self:remove_watch(fullpath)
  end

  if not self:skip(fullpath) then
    self.callback(fullpath, change_type)
  end
end

--- @package
--- @param path string The root directory to watch.
--- @return boolean started
function WatchDirs:start(path)
  local start_err = self:add_watch(path)
  if start_err then
    self:stop()
    self.opts.on_error(start_err)
    return false
  end

  --- "640K ought to be enough for anyone"
  --- Who has folders this deep?
  local max_depth = 100

  for name, type in
    vim.fs.dir(path, {
      depth = max_depth,
      skip = function(dir)
        return not self:skip(vim.fs.joinpath(path, dir), true)
      end,
    })
  do
    if type == 'directory' then
      local filepath = vim.fs.joinpath(path, name)
      if not self:skip(filepath, true) then
        local err, errname = self:add_watch(filepath)
        -- The directory may have disappeared since it was listed.
        if err and errname ~= 'ENOENT' then
          self.opts.on_error(err)
        end
      end
    end
  end
  return true
end

--- @package
function WatchDirs:stop()
  self.cancelled = true
  for path in pairs(self.handles) do
    self:remove_watch(path)
  end
  self.timer:stop()
  self.timer:close()
end

--- Initializes and starts a |uv_fs_event_t| recursively watching every directory underneath the
--- directory at path.
---
--- @param path string The path to watch. Must refer to a directory.
--- @param opts vim._watch.BackendOpts Additional options
--- @param callback vim._watch.Callback Callback for new events
--- @return fun()? cancel Stops all directory watchers; nil if startup failed.
return function(path, opts, callback)
  local watcher = WatchDirs.new(opts, callback)
  if not watcher:start(path) then
    return
  end
  return function()
    watcher:stop()
  end
end
