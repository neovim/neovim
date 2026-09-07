local bit = require('bit')
local watch = vim._watch
local log = require('vim.lsp.log')
local notify = require('vim._core.util').notify
local protocol = require('vim.lsp.protocol')

local M = {}

if vim.fn.has('win32') == 1 or vim.fn.has('mac') == 1 then
  M._watchfunc = watch.watch
elseif vim.fn.executable('inotifywait') == 1 then
  M._watchfunc = watch.inotify
else
  M._watchfunc = watch.watchdirs
end

--- @type table<integer, table<string, fun()>> client id -> registration id -> cancel
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
--- @type vim._watch.Filter
M._poll_exclude_pattern = {
  '**/.git/{objects,subtree-cache}/**',
  '**/node_modules/*/**',
  '**/.hg/store/**',
}

--- Resolves LSP workspace folders and relative patterns into filesystem watcher rules.
--- @param watchers lsp.FileSystemWatcher[]
--- @param workspace_folders lsp.WorkspaceFolder[]
--- @return vim._watch.Rule[]
local function watcher_rules(watchers, workspace_folders)
  local rules = {} --- @type vim._watch.Rule[]

  for _, w in ipairs(watchers) do
    local events --- @type vim._watch.FileChangeType[]?
    if w.kind then
      events = {}
      for change_type, lsp_change_type in pairs(to_lsp_change_type) do
        -- WatchKind is a bitmask, whereas FileChangeType is an enum.
        if bit.band(w.kind, bit.lshift(1, lsp_change_type - 1)) ~= 0 then
          table.insert(events, change_type)
        end
      end
    end

    local pattern = w.globPattern
    if type(pattern) == 'string' then
      for _, folder in ipairs(workspace_folders) do
        rules[#rules + 1] =
          { path = vim.uri_to_fname(folder.uri), pattern = pattern, events = events }
      end
    else
      local uri = type(pattern.baseUri) == 'string' and pattern.baseUri or pattern.baseUri.uri
      local base = vim.uri_to_fname(uri)
      local prefix = vim.fs.normalize(base):gsub('/$', '')

      rules[#rules + 1] = {
        path = base,
        -- Keep the base literal. '/' handles UNC paths; '#' avoids the parser's leading marker.
        pattern = vim.fn.escape(prefix, '\\/*?[]{}#') .. '/' .. pattern.pattern,
        events = events,
      }
    end
  end

  return rules
end

--- @param client vim.lsp.Client
--- @param err string
local function report_error(client, err)
  local name = string.format('LSP[%s]', client.name)
  local message = 'file watcher failed: ' .. err
  local level = vim.log.levels.ERROR

  -- Servers may register a nonexistent baseUri. Keep this informational
  -- and continue registering the other watchers.
  if err:match('^ENOENT:') then
    level = vim.log.levels.INFO
    log.info(name, message)
  else
    log.error(name, message)
  end

  notify(name, message, level, true)
end

--- Queues a file change, pruning consecutive duplicates per URI.
--- Changes are batched into a single notification per client.
---
--- @param client vim.lsp.Client
--- @param fullpath string
--- @param change_type vim._watch.FileChangeType
local function queue_change(client, fullpath, change_type)
  local client_id = client.id
  --- @type lsp.FileEvent
  local change = {
    uri = vim.uri_from_fname(fullpath),
    type = assert(
      to_lsp_change_type[change_type],
      'Must receive change type Created, Changed or Deleted'
    ),
  }

  local last_type = change_cache[client_id][change.uri]
  if last_type ~= change.type then
    change_queues[client_id] = change_queues[client_id] or {}
    table.insert(change_queues[client_id], change)
    change_cache[client_id][change.uri] = change.type
  end

  if not queue_timers[client_id] then
    queue_timers[client_id] = vim.defer_fn(function()
      --- @type lsp.DidChangeWatchedFilesParams
      local params = { changes = change_queues[client_id] }
      client:notify('workspace/didChangeWatchedFiles', params)

      queue_timers[client_id] = nil
      change_queues[client_id] = nil
      change_cache[client_id] = nil
    end, queue_timeout_ms)
  end
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

  local options = reg.registerOptions --[[@as lsp.DidChangeWatchedFilesRegistrationOptions]]
  local rules = watcher_rules(options.watchers, client.workspace_folders)

  local cancel = M._watchfunc(rules, {
    uvflags = { recursive = true },
    exclude_pattern = M._poll_exclude_pattern,
    on_error = function(err)
      report_error(client, err)
    end,
  }, function(fullpath, change_type)
    queue_change(client, fullpath, change_type)
  end)

  -- Acquire first so replacing an ID does not stop a shared backend between subscriptions.
  M.unregister(reg.id, client_id)
  registered[client_id][reg.id] = cancel
end

--- Unregisters the workspace/didChangeWatchedFiles capability dynamically.
---
--- @param id string Registration ID.
--- @param client_id integer Client ID.
function M.unregister(id, client_id)
  local client_registrations = registered[client_id]
  local cancel = client_registrations[id]

  client_registrations[id] = nil
  if not next(client_registrations) then
    registered[client_id] = nil
  end

  if cancel then
    cancel()
  end
end

--- @param client_id integer
function M.cancel(client_id)
  for id in pairs(registered[client_id]) do
    M.unregister(id, client_id)
  end

  registered[client_id] = nil
end

return M
