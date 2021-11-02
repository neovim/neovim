local log = require 'vim.lsp.log'

local M = {}
local fs_events_by_id = {}


local function make_notify_fn(client, path, kind)
  return function(err, filename, events)
    if err then
      log.error(err)
      return
    end
    log.trace('fs_event trigger', {path=path, filename=filename})
    local filepath
    local stat = vim.loop.fs_stat(path)
    -- TODO: path.join
    -- TODO: what if root_dir is not set? use getcwd? workspaceFolders?
    if stat and stat.type == 'directory' then
      filepath = client.config.root_dir .. '/' .. path .. '/' .. filename
    else
      filepath = client.config.root_dir .. '/' .. path
    end

    local uri = vim.uri_from_fname(filepath)
    local type

    -- kind is an uint (Created=1 | Change=2 | Delete=4)
    local ordinal
    if events.rename then
      if vim.loop.fs_stat(filepath) then
        type = vim.lsp.protocol.FileChangeType.Created
        ordinal = 1
      else
        type = vim.lsp.protocol.FileChangeType.Deleted
        ordinal = 4
      end
    else
      type = vim.lsp.protocol.FileChangeType.Changed
      ordinal = 2
    end
    -- TODO: no bitwise and operator on Lua 5.1 :(
    --if (kind & ordinal) ~= 0 then
    --  return
    --end
    --
    -- TODO: skip if type doesn't fit with kind
    -- TODO: debounce/batch events?
    local params = {
      -- changes: FileEvent[]
      --
      -- FileEvent:
      --  uri:
      --  type:
      changes = {
        {
          uri = uri,
          type = type
        },
      }
    }
    client.notify('workspace/didChangeWatchedFiles', params)
  end
end


function M.register(client, id, watchers)
  -- watchers: FileSystemWatcher[]
  --
  -- FileSystemWatcher:
  --  globPattern: string;
  --  kind?: uinteger;    (defaults to WatchKind.Create=1 | WatchKind.Change=2 | WatchKind.Delete=4)
  local fs_events = {}
  -- TODO: de-duplicate across clients to reduce the amount of watchers?
  fs_events_by_id[id] = fs_events
  for _, watcher in pairs(watchers) do
    -- TODO: figure out how to really handle the globPattern.
    -- Servers seem to ask for watches on directories and also provide globs like `*/**.java`
    for _, path in pairs(vim.fn.glob(watcher.globPattern, true, true)) do
      local fs_event = fs_events[path]
      if not fs_event then
        local flags = {}
        -- TODO: Must we close events to not leak them on vim exit?
        local event = vim.loop.new_fs_event()
        local ok, err = event:start(path, flags, make_notify_fn(client, path, watcher.kind or 7))
        if ok then
          fs_events[path] = event
        else
          log.warn('Error watching ' .. watcher.globPattern .. ': ' .. err)
        end
      end
    end
  end
end


function M.unregister(id)
  local fs_events = fs_events_by_id[id]
  if fs_events then
    fs_events_by_id[id] = nil
    for _, event in pairs(fs_events) do
      event:close()
    end
  end
end


return M
