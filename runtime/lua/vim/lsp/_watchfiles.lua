local bit = require('bit')
local glob = vim.glob
local watch = vim._watch
local log = require('vim.lsp.log')
local notify = require('vim._core.util').notify
local protocol = require('vim.lsp.protocol')
local lpeg = vim.lpeg

local M = {}

-- Use a bounded set to suppress repeat warnings without unbounded growth.
---@type table<string, true>
local logged_invalid_patterns = {}
---@type string[]
local logged_invalid_pattern_keys = {}
local logged_invalid_pattern_key_index = 1

---@param key string
local function remember_invalid_pattern(key)
  local old_key = logged_invalid_pattern_keys[logged_invalid_pattern_key_index]
  if old_key then
    logged_invalid_patterns[old_key] = nil
  end
  logged_invalid_patterns[key] = true
  logged_invalid_pattern_keys[logged_invalid_pattern_key_index] = key
  logged_invalid_pattern_key_index = logged_invalid_pattern_key_index % 20 + 1
end

--- Parses a glob pattern and logs invalid patterns once.
---@param pattern string
---@param client vim.lsp.Client
---@return vim.lpeg.Pattern?
local function glob_to_lpeg(pattern, client)
  local ok, pattern_or_err = pcall(glob.to_lpeg, pattern)
  if ok then
    return pattern_or_err
  end
  local key = string.format('%d:%s', client.id, pattern)
  if not logged_invalid_patterns[key] then
    log.error(
      string.format(
        'LSP[%s] skipping invalid workspace/didChangeWatchedFiles globPattern',
        client.name
      ),
      pattern,
      pattern_or_err
    )
    remember_invalid_pattern(key)
  end
end

if vim.fn.has('win32') == 1 or vim.fn.has('mac') == 1 then
  M._watchfunc = watch.watch
elseif vim.fn.executable('inotifywait') == 1 then
  M._watchfunc = watch.inotify
else
  M._watchfunc = watch.watchdirs
end

---@class (private) vim.lsp._watchfiles.Registration
---@field options lsp.DidChangeWatchedFilesRegistrationOptions
---@field workspace_folders lsp.WorkspaceFolder[]
---@field exclude_pattern vim.lpeg.Pattern
---@field watchfunc function
---@field refcount integer
---@field cancels function[]
---@field roots table<string, uv.fs_stat.result|false>
---@field ready boolean False until all backend watchers have been created.
---@field failed boolean

---@type table<integer, table<string, vim.lsp._watchfiles.Registration>> client id -> registration id
local registered = vim.defaulttable(function()
  return {}
end)

local queue_timeout_ms = 100
---@type table<integer, uv.uv_timer_t> client id -> libuv timer which will send queued changes at its timeout
local queue_timers = {}
---@type table<integer, lsp.FileEvent[]> client id -> set of queued changes to send in a single LSP notification
local change_queues = {}
---@type table<integer, table<string, lsp.FileChangeType>> client id -> URI -> last type of change processed
--- Used to prune consecutive events of the same type for the same file
local change_cache = vim.defaulttable()

---@type table<vim._watch.FileChangeType, lsp.FileChangeType>
local to_lsp_change_type = {
  [watch.FileChangeType.Created] = protocol.FileChangeType.Created,
  [watch.FileChangeType.Changed] = protocol.FileChangeType.Changed,
  [watch.FileChangeType.Deleted] = protocol.FileChangeType.Deleted,
}

--- Default excludes the same as VSCode's `files.watcherExclude` setting.
--- https://github.com/microsoft/vscode/blob/eef30e7165e19b33daa1e15e92fa34ff4a5df0d3/src/vs/workbench/contrib/files/browser/files.contribution.ts#L261
---@type vim.lpeg.Pattern parsed Lpeg pattern
M._poll_exclude_pattern = glob.to_lpeg('**/.git/{objects,subtree-cache}/**')
  + glob.to_lpeg('**/node_modules/*/**')
  + glob.to_lpeg('**/.hg/store/**')

--- Compiles watcher globs and groups them by base directory.
---
---@param client vim.lsp.Client
---@param watchers lsp.FileSystemWatcher[]
---@param workspace_folders lsp.WorkspaceFolder[]
---@return table<string, {pattern: vim.lpeg.Pattern, kind: lsp.WatchKind}[]>
local function compile_watchers(client, watchers, workspace_folders)
  ---@type table<string, {pattern: vim.lpeg.Pattern, kind: lsp.WatchKind}[]> by base_dir
  local watch_regs = vim.defaulttable()
  for _, w in ipairs(watchers) do
    local kind = w.kind
      or (protocol.WatchKind.Create + protocol.WatchKind.Change + protocol.WatchKind.Delete)
    local glob_pattern = w.globPattern

    if type(glob_pattern) == 'string' then
      local pattern = glob_to_lpeg(glob_pattern, client)
      if pattern then
        for _, folder in ipairs(workspace_folders) do
          local base_dir = vim.uri_to_fname(folder.uri)
          table.insert(watch_regs[base_dir], { pattern = pattern, kind = kind })
        end
      end
    else
      local base_uri = glob_pattern.baseUri
      local uri = type(base_uri) == 'string' and base_uri or base_uri.uri
      local base_dir = vim.uri_to_fname(uri)
      local pattern = glob_to_lpeg(glob_pattern.pattern, client)
      if pattern then
        local relative_pattern = lpeg.P(base_dir .. '/') * pattern --[[@as vim.lpeg.Pattern]]
        table.insert(watch_regs[base_dir], { pattern = relative_pattern, kind = kind })
      end
    end
  end
  return watch_regs
end

--- Checks root identity: a directory can be replaced without reporting a watcher error.
---@param roots table<string, uv.fs_stat.result|false>
---@return boolean
local function roots_unchanged(roots)
  for path, previous in pairs(roots) do
    local current = vim.uv.fs_stat(path)
    if
      not previous
      or not current
      or previous.dev ~= current.dev
      or previous.ino ~= current.ino
    then
      return false
    end
  end
  return true
end

--- Associates the registration ID with a matching watcher set or a new one.
--- The caller must start the watchers if the set was not reused.
---
---@param reg lsp.Registration
---@param client_id integer
---@param workspace_folders lsp.WorkspaceFolder[]
---@return vim.lsp._watchfiles.Registration
---@return boolean reused
local function acquire_registration(reg, client_id, workspace_folders)
  local register_options = reg.registerOptions --[[@as lsp.DidChangeWatchedFilesRegistrationOptions]]
  local client_registrations = registered[client_id]
  -- Servers may register replacements before unregistering identical watchers.
  -- Keep the backend alive until the last registration using it is removed.
  for _, registration in pairs(client_registrations) do
    if
      registration.ready
      and not registration.failed
      and registration.watchfunc == M._watchfunc
      and registration.exclude_pattern == M._poll_exclude_pattern
      and vim.deep_equal(registration.options, register_options)
      and vim.deep_equal(registration.workspace_folders, workspace_folders)
      and roots_unchanged(registration.roots)
    then
      if client_registrations[reg.id] ~= registration then
        registration.refcount = registration.refcount + 1
        M.unregister({ id = reg.id, method = reg.method }, client_id)
        client_registrations[reg.id] = registration
      end
      return registration, true
    end
  end

  M.unregister({ id = reg.id, method = reg.method }, client_id)
  client_registrations = registered[client_id]
  ---@type vim.lsp._watchfiles.Registration
  local registration = {
    options = vim.deepcopy(register_options),
    workspace_folders = vim.deepcopy(workspace_folders),
    exclude_pattern = M._poll_exclude_pattern,
    watchfunc = M._watchfunc,
    refcount = 1,
    cancels = {},
    roots = {},
    ready = false,
    failed = false,
  }
  client_registrations[reg.id] = registration
  return registration, false
end

--- Registers the workspace/didChangeWatchedFiles capability dynamically.
---
---@param reg lsp.Registration LSP Registration object.
---@param client_id integer Client ID.
function M.register(reg, client_id)
  local client = assert(vim.lsp.get_client_by_id(client_id), 'Client must be running')
  -- Ill-behaved servers may not honor the client capability and try to register
  -- anyway, so ignore requests when the user has opted out of the feature.
  local has_capability =
    vim.tbl_get(client.capabilities, 'workspace', 'didChangeWatchedFiles', 'dynamicRegistration')
  if not has_capability or not client.workspace_folders then
    return
  end
  local registration, reused = acquire_registration(reg, client_id, client.workspace_folders)
  if reused then
    return
  end
  local register_options = reg.registerOptions --[[@as lsp.DidChangeWatchedFilesRegistrationOptions]]
  local watch_regs = compile_watchers(client, register_options.watchers, client.workspace_folders)

  ---@param base_dir string
  local callback = function(base_dir)
    return function(fullpath, change_type)
      local registrations = watch_regs[base_dir]
      for _, w in ipairs(registrations) do
        local lsp_change_type = assert(
          to_lsp_change_type[change_type],
          'Must receive change type Created, Changed or Deleted'
        )
        -- e.g. match kind with Delete bit (0b0100) to Delete change_type (3)
        local kind_mask = bit.lshift(1, lsp_change_type - 1)
        local change_type_match = bit.band(w.kind, kind_mask) == kind_mask
        if w.pattern:match(fullpath) ~= nil and change_type_match then
          ---@type lsp.FileEvent
          local change = {
            uri = vim.uri_from_fname(fullpath),
            type = lsp_change_type,
          }

          local last_type = change_cache[client_id][change.uri]
          if last_type ~= change.type then
            change_queues[client_id] = change_queues[client_id] or {}
            table.insert(change_queues[client_id], change)
            change_cache[client_id][change.uri] = change.type
          end

          if not queue_timers[client_id] then
            queue_timers[client_id] = vim.defer_fn(function()
              ---@type lsp.DidChangeWatchedFilesParams
              local params = {
                changes = change_queues[client_id],
              }
              client:notify('workspace/didChangeWatchedFiles', params)
              queue_timers[client_id] = nil
              change_queues[client_id] = nil
              change_cache[client_id] = nil
            end, queue_timeout_ms)
          end

          break -- if an event matches multiple watchers, only send one notification
        end
      end
    end
  end

  for base_dir, watches in pairs(watch_regs) do
    local include_pattern = vim.iter(watches):fold(lpeg.P(false), function(acc, w)
      return acc + w.pattern
    end)

    registration.roots[base_dir] = vim.uv.fs_stat(base_dir) or false
    table.insert(
      registration.cancels,
      M._watchfunc(base_dir, {
        uvflags = {
          recursive = true,
        },
        -- include_pattern will ensure the pattern from *any* watcher definition for the
        -- base_dir matches. This first pass prevents polling for changes to files that
        -- will never be sent to the LSP server. A second pass in the callback is still necessary to
        -- match a *particular* pattern+kind pair.
        include_pattern = include_pattern,
        exclude_pattern = M._poll_exclude_pattern,
        on_error = function(err)
          registration.failed = true
          local name = string.format('LSP[%s]', client.name)
          local message = string.format('file watcher failed for %s', base_dir)
          local level = vim.log.levels.ERROR
          -- Servers may register a nonexistent baseUri. Keep this informational
          -- and continue registering the other watchers.
          if err:match('^ENOENT:') then
            level = vim.log.levels.INFO
            log.info(name, message, err)
          else
            log.error(name, message, err)
          end
          notify(name, message .. ': ' .. err, level, true)
        end,
      }, callback(base_dir))
    )
  end
  registration.ready = true
end

---@param registration vim.lsp._watchfiles.Registration
local function release(registration)
  registration.refcount = registration.refcount - 1
  if registration.refcount == 0 then
    for _, cancel in ipairs(registration.cancels) do
      cancel()
    end
  end
end

--- Unregisters the workspace/didChangeWatchedFiles capability dynamically.
---
---@param unreg lsp.Unregistration LSP Unregistration object.
---@param client_id integer Client ID.
function M.unregister(unreg, client_id)
  local client_registrations = registered[client_id]
  local registration = client_registrations[unreg.id]
  client_registrations[unreg.id] = nil
  if not next(client_registrations) then
    registered[client_id] = nil
  end
  if registration then
    release(registration)
  end
end

--- @param client_id integer
function M.cancel(client_id)
  local client_registrations = registered[client_id]
  registered[client_id] = nil
  for _, registration in pairs(client_registrations) do
    release(registration)
  end
end

return M
