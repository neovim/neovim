local M = {}

--- Called by builtin serverlist(). Returns all running servers in stdpath("run").
---
--- - TODO: track TCP servers, somehow.
--- - TODO: support Windows named pipes.
---
--- @param listed string[] Already listed servers
--- @return string[] # List of servers found on the current machine in stdpath("run").
function M.serverlist(listed)
  local socket_paths = vim.fs.find(function(name, _)
    return name:match('nvim.*')
  end, { path = vim.fn.stdpath('run'), type = 'socket', limit = math.huge })

  local found = {} ---@type string[]
  for _, socket in ipairs(socket_paths) do
    -- Don't list servers twice
    if not vim.list_contains(listed, socket) then
      local ok, chan = pcall(vim.fn.sockconnect, 'pipe', socket, { rpc = true })
      if ok and chan then
        -- Check that the server is responding
        -- TODO: do we need a timeout or error handling here?
        if vim.fn.rpcrequest(chan, 'nvim_get_chan_info', 0).id then
          table.insert(found, socket)
        end
        vim.fn.chanclose(chan)
      end
    end
  end

  return found
end

return M
