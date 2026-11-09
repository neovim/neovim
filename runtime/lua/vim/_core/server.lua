-- For "--listen", ":restart", and related remote/server functionality.

local time = require('vim._core.time')
local util = require('vim._core.util')

local M = {}

--- Queries Nvim `servers` for their PID and |v:useractive|, concurrently. Omits servers that don't
--- respond within `timeout` ms or before CTRL-C.
--- @param servers string[]
--- @param timeout integer
--- @return table<string, { pid: integer, active: integer }>
local function probe(servers, timeout)
  -- msgpack-rpc request: [type, msgid, method, params].
  local req = vim.mpack.encode({ 0, 0, 'nvim_eval', { '[getpid(), v:useractive]' } })
  local answers = {} ---@type table<string, { pid: integer, active: integer }>
  local pipes = {} ---@type uv.uv_pipe_t[]
  local pending = #servers

  -- Async, unlike vim.rpcrequest(): sends all requests here, `vim.wait()` below collects answers.
  -- TODO: Simplify by using sockconnect(), after vim.rpcrequest() gains async. #8658
  for _, sock in ipairs(servers) do
    local pipe = assert(vim.uv.new_pipe())
    table.insert(pipes, pipe)
    local function finish()
      if not pipe:is_closing() then
        pipe:close()
        pending = pending - 1
      end
    end
    pipe:connect(sock, function(connect_err)
      if connect_err then
        return finish()
      end
      local out = ''
      pipe:read_start(function(read_err, data)
        out = out .. (data or '')
        -- Response: [type, msgid, error, result]. Fails to decode until complete.
        local ok, msg = pcall(vim.mpack.decode, out)
        if ok and type(msg) == 'table' and msg[3] == vim.NIL and type(msg[4]) == 'table' then
          answers[sock] = { pid = msg[4][1], active = msg[4][2] }
        end
        if ok or read_err or not data then
          finish()
        end
      end)
      pipe:write(req)
    end)
  end

  -- Fast events only (no reentrancy), like vim.rpcrequest().
  vim.wait(timeout, function()
    return pending == 0
  end, nil, true)
  for _, pipe in ipairs(pipes) do
    if not pipe:is_closing() then
      pipe:close()
    end
  end
  return answers
end

--- Called by builtin serverlist(). Returns the combined server list (own + peers).
---
---@class vim.ServerInfo
---@field addr string Server address (socket path, named pipe, or TCP host:port).
---@field pid integer PID of the Nvim process.
---@field own boolean True if this server belongs to the current Nvim instance.
---@field active integer Timestamp of last user activity.

--- @param opts? table Options:
---              - opts.peer (boolean): If true, also discover peer servers.
---              - opts.info (boolean): If true, return a list of |vim.ServerInfo| dicts
---                instead of a list of addresses. Implies peer=true.
--- @param addrs string[] Internal ("own") addresses, from server_address_list.
--- @return string[]|vim.ServerInfo[]
function M.serverlist(opts, addrs)
  if type(opts) ~= 'table' then
    return addrs
  end

  local want_info = opts.info == true
  if opts.peer ~= true and not want_info then
    return addrs
  end

  local seen = {} ---@type table<string, true>
  for _, a in ipairs(addrs) do
    seen[a] = true
  end

  local peers ---@type string[]|vim.ServerInfo[]
  if want_info then
    local self_pid = vim.fn.getpid()
    local self_active = vim.v.useractive
    peers = vim.tbl_map(function(addr)
      return {
        addr = addr,
        pid = self_pid,
        own = true,
        active = self_active,
      }
    end, addrs)
  else
    peers = addrs
  end

  -- Discover peer servers in stdpath("run").
  -- TODO: track TCP servers, somehow.
  -- TODO: support Windows named pipes.
  local root = vim.fs.normalize(vim.fn.stdpath('run') .. '/..')
  local socket_paths = vim.fs.find(function(name, _)
    return name:match('nvim.*')
  end, { path = root, type = 'socket', limit = math.huge })

  socket_paths = vim.tbl_filter(function(sock)
    return not seen[sock]
  end, socket_paths)
  -- Only responding servers.
  local answers = probe(socket_paths, 1000)
  for _, sock in ipairs(socket_paths) do
    local answer = answers[sock]
    if answer and want_info then
      table.insert(peers, { addr = sock, pid = answer.pid, own = false, active = answer.active })
    elseif answer then
      table.insert(peers, sock)
    end
  end

  return peers
end

--- Implements `:connect` (no args) menu.
function M.select_connect()
  ---@type vim.ServerInfo[]
  local servers = vim.tbl_filter(function(s)
    return not s.own
  end, vim.fn.serverlist({ info = true }))
  table.sort(servers, function(a, b)
    return a.active > b.active
  end)
  local width = 0
  for _, s in ipairs(servers) do
    width = math.max(width, #vim.fs.basename(s.addr))
  end

  local addrs = {} ---@type string[]
  local texts = {} ---@type table<string, string> Address => menu item, e.g. "nvim.123.0  3 minutes ago".
  for _, s in ipairs(servers) do
    table.insert(addrs, s.addr)
    local active = s.active == 0 and '?' or time.fmt_ago(s.active) -- 0: No user activity.
    texts[s.addr] = ('%-' .. width .. 's  %s'):format(vim.fs.basename(s.addr), active)
  end
  for _, host in ipairs(require('vim.net._ssh').get_hosts()) do
    local addr = ('ssh://%s'):format(host)
    table.insert(addrs, addr)
    texts[addr] = addr
  end

  if #addrs == 0 then
    vim.api.nvim_echo({ { 'No servers found' } }, false, {})
    return
  end
  vim.ui.select(addrs, {
    prompt = 'Connect to:',
    format_item = function(addr)
      return texts[addr]
    end,
  }, function(addr)
    if not addr then
      return
    end
    local ok, err = pcall(vim.cmd.connect, { addr, magic = { file = false } })
    if not ok then
      ---@cast err string
      util.echo_err(util.cmd_errmsg(err))
    end
  end)
end

-- (Windows only) Canonical --listen address persisted across restarts.
M.restart_canonical_addr = nil ---@type string?

--- (Windows only)
--- Called on the new server via nvim_exec_lua RPC from the old server (:restart).
--- Windows named pipes can't be rebound immediately, so the new server starts on a
--- temporary bootstrap address and polls until the canonical address is reclaimable.
--- @param canonical_addr string  The original --listen address to reclaim.
--- @param expected_uis   integer Number of UIs expected to reattach (0 = don't wait).
function M.rebind_after_restart(canonical_addr, expected_uis)
  M.restart_canonical_addr = canonical_addr
  local bootstrap_addr = vim.v.servername -- Temporary autogenerated address.
  local poll_ms = 50
  local max_wait_ms = 30000
  local timer = assert(vim.uv.new_timer())

  -- Poll until the canonical address can be reclaimed (or timeout).
  local poll_elapsed = 0
  timer:start(poll_ms, poll_ms, function()
    vim.schedule(function()
      if timer:is_closing() then
        return
      end
      poll_elapsed = poll_elapsed + poll_ms
      if poll_elapsed >= max_wait_ms then
        timer:stop()
        timer:close()
        return
      end
      if not vim.list_contains(vim.fn.serverlist(), canonical_addr) then
        local ok = vim._with({ log_level = 5 }, function()
          return pcall(vim.fn.serverstart, canonical_addr)
        end)
        if not ok then
          return -- pipe still held by old server; retry next tick
        end
      end

      -- Wait for UIs to reattach, then retire the bootstrap address.
      local elapsed = 0
      timer:stop()
      timer:start(poll_ms, poll_ms, function()
        vim.schedule(function()
          if timer:is_closing() then
            return
          end
          elapsed = elapsed + poll_ms
          local all_uis = expected_uis <= 0 or #vim.api.nvim_list_uis() >= expected_uis
          if all_uis or elapsed >= max_wait_ms then
            if canonical_addr ~= bootstrap_addr then
              vim._with({ log_level = 5 }, function()
                pcall(vim.fn.serverstop, bootstrap_addr)
              end)
            end
            timer:stop()
            timer:close()
          end
        end)
      end)
    end)
  end)
end

-- Called by ex_restart(). Saves the current session and calls ex_restart() (again) with the
-- updated arguments.
--
-- TODO: https://github.com/neovim/neovim/issues/34204
--
--- @param eap vim._core.ExCmdArgs
--- @param extra { quit_cmd: string }
function M.ex_session_restart(eap, extra)
  local after_cmd = eap.args -- User-provided [command].
  assert(not after_cmd:find(']==]'))

  -- Use custom +cmd if given.
  local quit_cmd = extra.quit_cmd == '' and 'qall' or extra.quit_cmd

  -- Preserve v:this_session in the restarted Nvim.
  local this_session = vim.v.this_session
  assert(not this_session:find(']==]'))

  -- Nvim temp "root dir": "/tmp/…/nvim.<user>/"
  local tmproot = vim.fs.abspath(vim.fs.dirname(vim.fs.dirname(vim.fn.tempname())))
  assert(not tmproot:find(']==]'))
  local fd, session = vim.uv.fs_mkstemp(vim.fs.joinpath(tmproot, 'restart_session_XXXXXX'))
  if not fd then
    error('Failed to get temporary filename for restart session')
  end
  vim.uv.fs_close(fd)

  -- Write session
  local session_arg = vim.fn.fnameescape(session)
  vim.cmd('%argdelete')
  vim.cmd.mksession { session_arg, bang = true }

  -- Lua commands to restore the session and remove the session file
  local after_list = {}
  table.insert(after_list, ('vim.cmd("source %s")'):format(session_arg))
  table.insert(after_list, ('pcall(vim.fs.rm, [==[%s]==])'):format(session))
  table.insert(after_list, ('vim.v.this_session = [==[%s]==]'):format(this_session))
  if after_cmd ~= '' then
    table.insert(after_list, ('vim.cmd([==[%s]==])'):format(after_cmd))
  end
  local after = 'lua ' .. table.concat(after_list, ';')

  -- Restart Neovim and run our Lua commands
  local success, msg = pcall(function()
    -- "+:::" dummy prefix tells the C handler that this is actually a non-bang restart.
    -- Then v:startreason (if any) can be preserved.
    vim.cmd.restart { '+:::', quit_cmd, after, bang = true }
  end)

  if not success then
    --- @cast msg string
    vim.fs.rm(session, { force = true })

    -- Trim error message to be equivalent to `:restart!`
    if msg:find('Vim:') then
      util.echo_err(util.cmd_errmsg(msg))
    else
      error(msg)
    end
  end
end

return M
