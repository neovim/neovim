local bit = require('bit')
local glob = vim.glob
local watch = vim._watch
local protocol = require('vim.lsp.protocol')
local ms = protocol.Methods
local lpeg = vim.lpeg

local M = {}

if vim.fn.has('win32') == 1 or vim.fn.has('mac') == 1 then
  M._watchfunc = watch.watch
elseif vim.fn.executable('inotifywait') == 1 then
  M._watchfunc = watch.inotify
else
  M._watchfunc = watch.watchdirs
end

---@type table<integer, table<string, function[]>> client id -> registration id -> cancel function
local cancels = vim.defaulttable()

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
  local register_options = reg.registerOptions --[[@as lsp.DidChangeWatchedFilesRegistrationOptions]]
  ---@type table<string, {pattern: vim.lpeg.Pattern, kind: lsp.WatchKind}[]> by base_dir
  local watch_regs = vim.defaulttable()
  for _, w in ipairs(register_options.watchers) do
    local kind = w.kind
      or (protocol.WatchKind.Create + protocol.WatchKind.Change + protocol.WatchKind.Delete)
    local glob_pattern = w.globPattern

    if type(glob_pattern) == 'string' then
      local pattern = glob.to_lpeg(glob_pattern)
      if not pattern then
        error('Cannot parse pattern: ' .. glob_pattern)
      end
      for _, folder in ipairs(client.workspace_folders) do
        local base_dir = vim.uri_to_fname(folder.uri)
        table.insert(watch_regs[base_dir], { pattern = pattern, kind = kind })
      end
    else
      local base_uri = glob_pattern.baseUri
      local uri = type(base_uri) == 'string' and base_uri or base_uri.uri
      local base_dir = vim.uri_to_fname(uri)
      local pattern = glob.to_lpeg(glob_pattern.pattern)
      if not pattern then
        error('Cannot parse pattern: ' .. glob_pattern.pattern)
      end
      pattern = lpeg.P(base_dir .. '/') * pattern
      table.insert(watch_regs[base_dir], { pattern = pattern, kind = kind })
    end
  end

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
              client.notify(ms.workspace_didChangeWatchedFiles, params)
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

    table.insert(
      cancels[client_id][reg.id],
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
      }, callback(base_dir))
    )
  end
end

--- Unregisters the workspace/didChangeWatchedFiles capability dynamically.
---
---@param unreg lsp.Unregistration LSP Unregistration object.
---@param client_id integer Client ID.
function M.unregister(unreg, client_id)
  local client_cancels = cancels[client_id]
  local reg_cancels = client_cancels[unreg.id]
  while #reg_cancels > 0 do
    table.remove(reg_cancels)()
  end
  client_cancels[unreg.id] = nil
  if not next(cancels[client_id]) then
    cancels[client_id] = nil
  end
end

--- @param client_id integer
function M.cancel(client_id)
  for _, reg_cancels in pairs(cancels[client_id]) do
    for _, cancel in pairs(reg_cancels) do
      cancel()
    end
  end
end

return M
