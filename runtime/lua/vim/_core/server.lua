local M = {}

--- Helper function for serverlist(), this returns all the currently running servers
--- in stdpath("run"). Does not include named pipes or TCP servers.
---
--- @return string[] A list of currently running servers in stdpath("run")
function M.serverlist()
  -- TODO: also get named pipes on Windows
  local socket_paths = vim.fs.find(function(name, _)
    return name:match('nvim.*')
  end, { path = vim.fn.stdpath('run'), type = 'socket', limit = math.huge })

  local running_sockets = {}
  for _, socket in ipairs(socket_paths) do
    local ok, chan = pcall(vim.fn.sockconnect, 'pipe', socket, { rpc = true })
    if ok and chan then
      if vim.fn.rpcrequest(chan, 'nvim_get_chan_info', 0).id then
        table.insert(running_sockets, socket)
      end
      vim.fn.chanclose(chan)
    end
  end

  return running_sockets
end

return M
