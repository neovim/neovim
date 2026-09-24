local uv = vim.uv
local log = vim.log.new({ name = 'nvim-watch' })

local M = {}

--- @enum vim._watch.FileChangeType
--- Types of events watchers will emit.
M.FileChangeType = {
  Created = 1,
  Changed = 2,
  Deleted = 3,
}

--- A glob string or compiled LPeg pattern. Strings match full paths using `/` separators.
--- Glob syntax follows [vim.glob] (LSP 3.17).
--- @alias vim._watch.Pattern string|vim.lpeg.Pattern

--- A list matches if any of its patterns matches. An empty list matches nothing.
--- @alias vim._watch.Filter vim._watch.Pattern|vim._watch.Pattern[]

--- Option and rule tables must not be modified while watching.
--- @class vim._watch.Opts
---
--- @field debounce? integer ms
---
--- Handles watcher failures and invalid globs, with root and pattern context in the message.
--- Invalid globs are skipped. Defaults to logging at ERROR in nvim-watch.log.
--- @field on_error? fun(err: string)
---
--- Only changes matching this filter are reported. Parent directories remain watched for matching
--- descendants. See vim._watch.Pattern for glob syntax. When nil, matches any path.
--- @field include_pattern? vim._watch.Filter
---
--- Changes matching this filter are not reported. With watchdirs(), excluding a subdirectory
--- excludes its entire subtree. When nil, matches nothing.
--- @field exclude_pattern? vim._watch.Filter

--- @alias vim._watch.Callback fun(path: string, change_type: vim._watch.FileChangeType)

--- @class vim._watch.watch.Opts : vim._watch.Opts
--- @field uvflags? uv.fs_event_start.flags See |uv.fs_event_start()|.

--- Rules sharing a root use one backend watcher. Each event is reported once per root if any
--- rule matches, subject to the include_pattern and exclude_pattern options.
--- @class vim._watch.Rule
--- @field path string Root to watch.
--- @field pattern? vim._watch.Filter Matches full paths; nil matches everything.
--- @field events? vim._watch.FileChangeType[] Defaults to all event types.

--- @class (private) vim._watch.BackendOpts : vim._watch.watch.Opts
--- @field include_pattern? vim.lpeg.Pattern
--- @field exclude_pattern? vim.lpeg.Pattern
--- @field on_error fun(err: string)

--- @alias vim._watch.Backend fun(path: string, opts: vim._watch.BackendOpts, callback: vim._watch.Callback): (fun())?

--- @class (private) vim._watch.Subscriber
--- @field callback vim._watch.Callback
--- @field on_error fun(err: string)

--- @class (private) vim._watch.Shared
--- @field key table
--- @field stat? uv.fs_stat.result
--- @field failed boolean
--- @field subscribers table<vim._watch.Subscriber, true>
--- @field cancel? fun()

--- @type table<'watch'|'watchdirs'|'inotify', table<string, table<vim._watch.Shared, true>>>
local shared = { watch = {}, watchdirs = {}, inotify = {} }

--- Counts backend watchers with outstanding subscriptions, excluding failed starts.
--- @return {watch: integer, watchdirs: integer, inotify: integer}
function M.active()
  local active = { watch = 0, watchdirs = 0, inotify = 0 }

  for name, paths in pairs(shared) do
    for _, entries in pairs(paths) do
      active[name] = active[name] + vim.tbl_count(entries)
    end
  end

  return active
end

--- An omitted filter matches everything; invalid or empty filters return nil.
--- @param filter vim._watch.Filter?
--- @param on_error fun(err: string)
--- @return vim.lpeg.Pattern?
local function compile(filter, on_error)
  if filter == nil then
    return vim.lpeg.P(true)
  elseif type(filter) == 'userdata' then
    return filter --[[@as vim.lpeg.Pattern]]
  elseif type(filter) == 'string' then
    local ok, pattern = pcall(vim.glob.to_lpeg, filter)
    if not ok then
      on_error(('Invalid glob %q: %s'):format(filter, pattern))
      return nil
    end

    return pattern
  end

  local pattern --- @type vim.lpeg.Pattern?

  for _, item in ipairs(filter) do
    local p = compile(item, on_error)
    if p then
      pattern = pattern and pattern + p or p
    end
  end

  return pattern
end

--- @param entry vim._watch.Shared
--- @param method 'callback'|'on_error'
--- @param ... any
local function emit(entry, method, ...)
  local first_error

  -- Callbacks can subscribe or cancel other subscriptions while handling an event.
  for _, subscriber in ipairs(vim.tbl_keys(entry.subscribers)) do
    if entry.subscribers[subscriber] then
      local ok, err = pcall(subscriber[method], ...)
      if not ok then
        first_error = first_error or tostring(err)
      end
    end
  end

  if first_error then
    error(first_error)
  end
end

--- @param name 'watch'|'watchdirs'|'inotify'
--- @param backend vim._watch.Backend
--- @param path string
--- @param opts vim._watch.watch.Opts
--- @param rules {pattern: vim._watch.Filter?, events: vim._watch.FileChangeType[]?}[]
--- @param subscriber vim._watch.Subscriber
--- @return fun()
local function subscribe(name, backend, path, opts, rules, subscriber)
  local key = {
    include_pattern = opts.include_pattern,
    exclude_pattern = opts.exclude_pattern,
    debounce = name == 'watchdirs' and (opts.debounce or 500) or nil,
    uvflags = name == 'watch' and (opts.uvflags or {}) or nil,
    rules = rules,
  }

  -- Validate every subscription, even when reusing a backend. Invalid globs do not mean the
  -- backend has failed, and each subscriber should receive its own diagnostics.
  local include_pattern = compile(key.include_pattern, subscriber.on_error)
  local exclude_pattern = key.exclude_pattern and compile(key.exclude_pattern, subscriber.on_error)
  local compiled = {} --- @type {pattern: vim.lpeg.Pattern, events: vim._watch.FileChangeType[]?}[]
  local include = vim.lpeg.P(false)

  for _, rule in ipairs(key.rules) do
    local pattern = compile(rule.pattern, subscriber.on_error)
    if pattern then
      compiled[#compiled + 1] = { pattern = pattern, events = rule.events }
      include = include + pattern
    end
  end

  if not include_pattern or #compiled == 0 then
    return function() end
  end

  local stat = uv.fs_stat(path)
  local entry --- @type vim._watch.Shared?

  for r in pairs(shared[name][path] or {}) do
    if
      not r.failed
      and stat
      and r.stat
      and stat.dev == r.stat.dev
      and stat.ino == r.stat.ino
      and vim.deep_equal(r.key, key)
    then
      entry = r
      break
    end
  end

  if entry then
    entry.subscribers[subscriber] = true
  else
    entry = { key = key, stat = stat, failed = false, subscribers = { [subscriber] = true } }

    --- @type vim._watch.BackendOpts
    local backend_opts = {
      debounce = key.debounce,
      uvflags = key.uvflags,
      -- Both filters must match from the beginning of the full path.
      include_pattern = #include_pattern * include,
      exclude_pattern = exclude_pattern,
      on_error = function(err)
        entry.failed = true
        emit(entry, 'on_error', err)
      end,
    }

    entry.cancel = backend(path, backend_opts, function(fullpath, change_type)
      for _, rule in ipairs(compiled) do
        if
          rule.pattern:match(fullpath) ~= nil
          and (not rule.events or vim.list_contains(rule.events, change_type))
        then
          emit(entry, 'callback', fullpath, change_type)
          return
        end
      end
    end)

    if not entry.cancel then
      return function() end
    end

    -- Publish only after setup completes, so reentrant calls cannot reuse partial watchers.
    shared[name][path] = shared[name][path] or {}
    shared[name][path][entry] = true
  end

  return function()
    if not entry.subscribers[subscriber] then
      return
    end

    entry.subscribers[subscriber] = nil

    if not next(entry.subscribers) then
      shared[name][path][entry] = nil
      if not next(shared[name][path]) then
        shared[name][path] = nil
      end

      assert(entry.cancel)()
    end
  end
end

--- Compatible calls share a backend until their last subscription is cancelled. Glob descriptions
--- are compared by value, LPeg patterns by identity. Failed or replaced roots are never reused.
--- @param name 'watch'|'watchdirs'|'inotify'
--- @param backend vim._watch.Backend
--- @param path string|vim._watch.Rule[]
--- @param opts vim._watch.watch.Opts?
--- @param callback vim._watch.Callback
--- @return fun()
local function start_watch(name, backend, path, opts, callback)
  vim.validate('path', path, { 'string', 'table' })
  vim.validate('opts', opts, 'table', true)
  vim.validate('callback', callback, 'function')

  opts = opts or {}
  local on_error = opts.on_error or log.error

  if type(path) == 'string' then
    path = { { path = path } }
  end

  --- @type table<string, {pattern: vim._watch.Filter?, events: vim._watch.FileChangeType[]?}[]>
  local by_path = vim.defaulttable()

  for _, rule in ipairs(path) do
    table.insert(
      by_path[vim.fs.normalize(rule.path)],
      { pattern = rule.pattern, events = rule.events }
    )
  end

  local cancels = {} --- @type (fun())[]

  local function cancel_all()
    for _, cancel in ipairs(cancels) do
      cancel()
    end
  end

  for root, rules in pairs(by_path) do
    local ok, result = pcall(subscribe, name, backend, root, opts, rules, {
      callback = callback,
      on_error = function(err)
        on_error(('%s (watching %s)'):format(err, root))
      end,
    })

    if not ok then
      cancel_all()
      error(result, 0)
    end

    cancels[#cancels + 1] = result
  end

  return cancel_all
end

--- Decides if `path` should be skipped.
---
--- @param path string
--- @param opts vim._watch.BackendOpts
--- @param directory? boolean Ignore include_pattern when traversing directories.
local function skip(path, opts, directory)
  if not directory and opts.include_pattern and opts.include_pattern:match(path) == nil then
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
--- @param opts vim._watch.BackendOpts Additional options:
---      - uvflags (table|nil)
---                 Same flags as accepted by |uv.fs_event_start()|
--- @param callback vim._watch.Callback Callback for new events
--- @return fun()? cancel Stops the watcher; nil if startup failed.
local function watch(path, opts, callback)
  local on_error = opts.on_error
  local handle = assert(uv.new_fs_event())

  local watching_dir = (uv.fs_stat(path) or {}).type == 'directory'

  local _, start_err = handle:start(path, opts.uvflags or {}, function(err, filename, events)
    if err then
      return on_error(err)
    end
    local fullpath = path
    if filename and watching_dir then
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
        if staterr then
          return on_error(staterr)
        end
        change_type = M.FileChangeType.Created
      end
    elseif events.change then
      change_type = M.FileChangeType.Changed
    end
    callback(fullpath, change_type)
  end)

  if start_err then
    handle:close()
    on_error(start_err)
    return nil
  end

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
--- @param opts vim._watch.BackendOpts Additional options
--- @param callback vim._watch.Callback Callback for new events
--- @return fun()? cancel Stops all directory watchers; nil if startup failed.
local function watchdirs(path, opts, callback)
  local on_error = opts.on_error
  local debounce = opts.debounce or 500
  local cancelled = false

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
      if cancelled then
        return
      end
      if err then
        return on_error(err)
      end

      local fullpath = vim.fs.joinpath(filepath, filename)
      if skip(fullpath, opts) then
        -- An unmatched directory can contain matching descendants. Track its creation/deletion
        -- even when no event for the directory itself will be reported.
        if
          skip(fullpath, opts, true)
          or not events.rename
          or (not handles[fullpath] and (uv.fs_stat(fullpath) or {}).type ~= 'directory')
        then
          return
        end
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
        if cancelled then
          return
        end

        ---@type vim._watch.FileChangeType
        local change_type
        if stat then
          change_type = changed and M.FileChangeType.Changed or M.FileChangeType.Created
          if stat.type == 'directory' then
            local handle = handles[fullpath]
            if not handle then
              handle = assert(uv.new_fs_event())
              handles[fullpath] = handle
              local _, err, errname = handle:start(fullpath, {}, create_on_change(fullpath))
              if err then
                handle:close()
                handles[fullpath] = nil
                -- The directory may have disappeared since fs_stat().
                if errname ~= 'ENOENT' then
                  on_error(err)
                end
              end
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

        if not skip(fullpath, opts) then
          callback(fullpath, change_type)
        end
      end)
    end
    filechanges = {}
  end

  local root_handle = assert(uv.new_fs_event())
  handles[path] = root_handle
  local _, start_err = root_handle:start(path, {}, create_on_change(path))

  if start_err then
    root_handle:close()
    timer:close()
    on_error(start_err)
    return nil
  end

  --- "640K ought to be enough for anyone"
  --- Who has folders this deep?
  local max_depth = 100

  for name, type in
    vim.fs.dir(path, {
      depth = max_depth,
      skip = function(dir)
        return not opts.exclude_pattern
          or opts.exclude_pattern:match(vim.fs.joinpath(path, dir)) == nil
      end,
    })
  do
    if type == 'directory' then
      local filepath = vim.fs.joinpath(path, name)
      if not skip(filepath, opts, true) then
        local handle = assert(uv.new_fs_event())
        handles[filepath] = handle
        local _, err, errname = handle:start(filepath, {}, create_on_change(filepath))
        if err then
          handle:close()
          handles[filepath] = nil
          -- The directory may have disappeared since it was listed.
          if errname ~= 'ENOENT' then
            on_error(err)
          end
        end
      end
    end
  end

  return function()
    cancelled = true
    for fullpath, handle in pairs(handles) do
      if not handle:is_closing() then
        handle:close()
      end
      handles[fullpath] = nil
    end
    timer:stop()
    timer:close()
  end
end

--- @param data string
--- @param opts vim._watch.BackendOpts
--- @param callback vim._watch.Callback
local function on_inotifywait_output(data, opts, callback)
  local d = vim.split(data, '%s+')

  -- only consider the last reported event
  local path, event, file = d[1], d[2], d[#d]
  local fullpath = vim.fs.joinpath(path, file)

  if skip(fullpath, opts) then
    return
  end

  --- @type integer
  local change_type

  if event == 'CREATE' then
    change_type = M.FileChangeType.Created
  elseif event == 'DELETE' then
    change_type = M.FileChangeType.Deleted
  elseif event == 'MODIFY' then
    change_type = M.FileChangeType.Changed
  elseif event == 'MOVED_FROM' then
    change_type = M.FileChangeType.Deleted
  elseif event == 'MOVED_TO' then
    change_type = M.FileChangeType.Created
  end

  if change_type then
    callback(fullpath, change_type)
  end
end

--- @param path string The path to watch. Must refer to a directory.
--- @param opts vim._watch.BackendOpts
--- @param callback vim._watch.Callback Callback for new events
--- @return fun()? cancel Stops the process; nil if startup failed.
local function inotify(path, opts, callback)
  local on_error = opts.on_error
  local cancelled = false
  local ok, obj = pcall(vim.system, {
    'inotifywait',
    '--quiet', -- suppress startup messages
    '--no-dereference', -- don't follow symlinks
    '--monitor', -- keep listening for events forever
    '--recursive',
    '--event',
    'create',
    '--event',
    'delete',
    '--event',
    'modify',
    '--event',
    'move',
    string.format('@%s/.git', path), -- ignore git directory
    path,
  }, {
    stderr = function(err, data)
      if err then
        on_error(err)
        return
      end

      if data and #vim.trim(data) > 0 then
        if vim.fn.has('linux') == 1 and vim.startswith(data, 'Failed to watch') then
          data = 'inotify(7) limit reached, see :h inotify-limitations for more info.'
        end
        on_error(data)
      end
    end,
    stdout = function(err, data)
      if err then
        on_error(err)
        return
      end

      for line in vim.gsplit(data or '', '\n', { plain = true, trimempty = true }) do
        on_inotifywait_output(line, opts, callback)
      end
    end,
    -- --latency is locale dependent but tostring() isn't and will always have '.' as decimal point.
    env = { LC_NUMERIC = 'C' },
  }, function(result)
    if not cancelled then
      on_error(('inotifywait exited with code %d'):format(result.code))
    end
  end)

  if not ok then
    on_error(obj)
    return nil
  end

  return function()
    cancelled = true
    obj:kill(2)
  end
end

--- Watches a path or set of rules. Compatible subscriptions share a backend watcher.
--- @param path string|vim._watch.Rule[]
--- @param opts? vim._watch.watch.Opts
--- @param callback vim._watch.Callback
--- @return fun() cancel Releases this subscription; the last cancellation stops the backend.
function M.watch(path, opts, callback)
  return start_watch('watch', watch, path, opts, callback)
end

--- Recursively watches directories. Compatible subscriptions share a backend watcher.
--- @param path string|vim._watch.Rule[] Roots must be directories.
--- @param opts? vim._watch.Opts
--- @param callback vim._watch.Callback
--- @return fun() cancel Releases this subscription; the last cancellation stops the backend.
function M.watchdirs(path, opts, callback)
  return start_watch('watchdirs', watchdirs, path, opts, callback)
end

--- Recursively watches directories using inotifywait. Compatible subscriptions share a process.
--- @param path string|vim._watch.Rule[] Roots must be directories.
--- @param opts? vim._watch.Opts
--- @param callback vim._watch.Callback
--- @return fun() cancel Releases this subscription; the last cancellation stops the backend.
function M.inotify(path, opts, callback)
  return start_watch('inotify', inotify, path, opts, callback)
end

return M
