-- For "--listen" and related functionality.

local M = {}

--- Called by builtin serverlist(). Returns the combined server list (own + peers).
---
--- @param opts? table Options:
---              - opts.peer is true, also discover peer servers.
--- @param addrs string[] Internal ("own") addresses, from `server_address_list`.
--- @return string[] # Combined list of servers (own + peers).
function M.serverlist(opts, addrs)
  if type(opts) ~= 'table' or not opts.peer then
    return addrs
  end

  -- Discover peer servers in stdpath("run").
  -- TODO: track TCP servers, somehow.
  -- TODO: support Windows named pipes.
  local root = vim.fs.normalize(vim.fn.stdpath('run') .. '/..')
  local socket_paths = vim.fs.find(function(name, _)
    return name:match('nvim.*')
  end, { path = root, type = 'socket', limit = math.huge })

  for _, socket in ipairs(socket_paths) do
    if not vim.list_contains(addrs, socket) then
      local ok, chan = pcall(vim.fn.sockconnect, 'pipe', socket, { rpc = true })
      if ok and chan then
        -- Check that the server is responding
        -- TODO: do we need a timeout or error handling here?
        if vim.fn.rpcrequest(chan, 'nvim_get_chan_info', 0).id then
          table.insert(addrs, socket)
        end
        vim.fn.chanclose(chan)
      end
    end
  end

  return addrs
end

return M
