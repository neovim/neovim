local log = require 'vim.lsp.log'

local M = {}
local watchers_by_id = {}


local function make_notify_fn(client, path, kind)
  return function(err, filename, events)
    -- What do to on error, log it?
    PL('err', err)
    PL('path', path, 'filename', filename)

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
    if events.rename then
      if vim.loop.fs_stat(filepath) then
        type = vim.lsp.protocol.FileChangeType.Created
      else
        type = vim.lsp.protocol.FileChangeType.Deleted
      end
    else
      type = vim.lsp.protocol.FileChangeType.Changed
    end
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
    PL('notify', params)
    client.notify('workspace/didChangeWatchedFiles', params)
  end
end


function M.register(client, id, watchers)
  -- watchers: FileSystemWatcher[]
  --
  -- FileSystemWatcher:
  --  globPattern: string;
  --  kind?: uinteger;    (defaults to WatchKind.Create | WatchKind.Change | WatchKind.Delete)
  --
  -- WatchKind:
  --   Create = 1
  --   Change = 2
  --   Delete = 4
  --
  local fs_events = {}
  watchers_by_id[id] = fs_events
  for _, watcher in pairs(watchers) do
    -- TODO: figure out how to really handle the globPattern.
    -- Servers seem to ask for watches on directories and also provide globs like `*/**.java`
    for _, path in pairs(vim.fn.glob(watcher.globPattern, true, true)) do
      local fs_event = fs_events[path]
      if not fs_event then
        local flags = {}
        -- TODO: Must we close events to not leak them on vim exit?
        local event = vim.loop.new_fs_event()
        local ok, err = event:start(path, flags, make_notify_fn(client, path, watcher.kind))
        if ok then
          fs_events[path] = {event, client}
        else
          log.warn('Error watching ' .. watcher.globPattern .. ': ' .. err)
        end
      end
    end
  end
end


function M.unregister(id)
  local watchers = watchers_by_id[id]
  if watchers then
    watchers_by_id[id] = nil
    -- TODO: close fs_events
  end
end


return M
