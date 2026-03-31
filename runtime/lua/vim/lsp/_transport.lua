local uv = vim.uv
local log = require('vim.lsp.log')

local is_win = vim.fn.has('win32') == 1

--- Checks whether a given path exists and is a directory.
---@param filename string path to check
---@return boolean
local function is_dir(filename)
  local stat = uv.fs_stat(filename)
  return stat and stat.type == 'directory' or false
end

--- @class (private) vim.lsp.rpc.Transport
--- @field write fun(self: vim.lsp.rpc.Transport, msg: string)
--- @field is_closing fun(self: vim.lsp.rpc.Transport): boolean
--- @field terminate fun(self: vim.lsp.rpc.Transport)

--- @class (private,exact) vim.lsp.rpc.Transport.Run : vim.lsp.rpc.Transport
--- @field new fun(): vim.lsp.rpc.Transport.Run
--- @field sysobj? vim.SystemObj
local TransportRun = {}

--- @return vim.lsp.rpc.Transport.Run
function TransportRun.new()
  return setmetatable({}, { __index = TransportRun })
end

--- @param cmd string[] Command to start the LSP server.
--- @param extra_spawn_params? vim.lsp.rpc.ExtraSpawnParams
--- @param on_read fun(err: any, data: string)
--- @param on_exit fun(code: integer, signal: integer)
function TransportRun:run(cmd, extra_spawn_params, on_read, on_exit)
  local function on_stderr(_, chunk)
    if chunk then
      log.error('rpc', cmd[1], 'stderr', chunk)
    end
  end

  extra_spawn_params = extra_spawn_params or {}

  if extra_spawn_params.cwd then
    assert(is_dir(extra_spawn_params.cwd), 'cwd must be a directory')
  end

  local detached = not is_win
  if extra_spawn_params.detached ~= nil then
    detached = extra_spawn_params.detached
  end

  local ok, sysobj_or_err = pcall(vim.system, cmd, {
    stdin = true,
    stdout = on_read,
    stderr = on_stderr,
    cwd = extra_spawn_params.cwd,
    env = extra_spawn_params.env,
    detach = detached,
  }, function(obj)
    on_exit(obj.code, obj.signal)
  end)

  if not ok then
    local err = sysobj_or_err --[[@as string]]
    local sfx = err:match('ENOENT')
        and '. The language server is either not installed, missing from PATH, or not executable.'
      or string.format(' with error message: %s', err)

    error(('Spawning language server with cmd: `%s` failed%s'):format(vim.inspect(cmd), sfx))
  end

  self.sysobj = sysobj_or_err --[[@as vim.SystemObj]]
end

function TransportRun:write(msg)
  assert(self.sysobj):write(msg)
end

function TransportRun:is_closing()
  return self.sysobj == nil or self.sysobj:is_closing()
end

function TransportRun:terminate()
  assert(self.sysobj):kill(15)
end

--- @class (private,exact) vim.lsp.rpc.Transport.Connect : vim.lsp.rpc.Transport
--- @field new fun(): vim.lsp.rpc.Transport.Connect
--- @field handle? uv.uv_pipe_t|uv.uv_tcp_t
--- Connect returns a PublicClient synchronously so the caller
--- can immediately send messages before the connection is established
--- -> Need to buffer them until that happens
--- @field connected boolean
--- @field closing boolean
--- @field msgbuf vim.Ringbuf
--- @field on_exit? fun(code: integer, signal: integer)
local TransportConnect = {}

--- @return vim.lsp.rpc.Transport.Connect
function TransportConnect.new()
  return setmetatable({
    connected = false,
    -- size should be enough because the client can't really do anything until initialization is done
    -- which required a response from the server - implying the connection got established
    msgbuf = vim.ringbuf(10),
    closing = false,
  }, { __index = TransportConnect })
end

--- @param host_or_path string
--- @param port? integer
--- @param on_read fun(err: any, data: string)
--- @param on_exit? fun(code: integer, signal: integer)
function TransportConnect:connect(host_or_path, port, on_read, on_exit)
  self.on_exit = on_exit
  self.handle = (
    port and assert(uv.new_tcp(), 'Could not create new TCP socket')
    or assert(uv.new_pipe(false), 'Pipe could not be opened.')
  )

  local function on_connect(err)
    if err then
      local address = not port and host_or_path or (host_or_path .. ':' .. port)
      vim.schedule(function()
        vim.notify(
          string.format('Could not connect to %s, reason: %s', address, vim.inspect(err)),
          vim.log.levels.WARN
        )
      end)
      return
    end
    self.handle:read_start(on_read)
    self.connected = true
    for msg in self.msgbuf do
      self.handle:write(msg)
    end
  end

  if not port then
    self.handle:connect(host_or_path, on_connect)
    return
  end

  --- @diagnostic disable-next-line:param-type-mismatch bad UV typing
  local info = uv.getaddrinfo(host_or_path, nil)
  local resolved_host = info and info[1] and info[1].addr or host_or_path
  self.handle:connect(resolved_host, port, on_connect)
end

function TransportConnect:write(msg)
  if self.connected then
    local _, err = self.handle:write(msg)
    if err and not self.closing then
      log.error('Error on handle:write: %q', err)
    end
    return
  end

  self.msgbuf:push(msg)
end

function TransportConnect:is_closing()
  return self.closing
end

function TransportConnect:terminate()
  if self.closing then
    return
  end
  self.closing = true
  if self.handle then
    self.handle:shutdown()
    self.handle:close()
  end
  if self.on_exit then
    self.on_exit(0, 0)
  end
end

return {
  TransportRun = TransportRun,
  TransportConnect = TransportConnect,
}
