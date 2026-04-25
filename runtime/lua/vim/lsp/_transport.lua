local uv = vim.uv
local log = require('vim.lsp.log')

--- Interface for transport implementations.
---
--- @class (private) vim.lsp.rpc.Transport
--- @field listen fun(self: vim.lsp.rpc.Transport, on_read: fun(err: any, data: string), on_exit: fun(code: integer, signal: integer))
--- @field write fun(self: vim.lsp.rpc.Transport, msg: string)
--- @field is_closing fun(self: vim.lsp.rpc.Transport): boolean
--- @field terminate fun(self: vim.lsp.rpc.Transport)

--- Transport backed by newly spawned process using `vim.system()`.
---
--- @class (private) vim.lsp.rpc.Transport.Run : vim.lsp.rpc.Transport
--- @field cmd string[] Command to start the LSP server.
--- @field extra_spawn_params? vim.lsp.rpc.ExtraSpawnParams
--- @field sysobj? vim.SystemObj
local TransportRun = {}

--- @param cmd string[] Command to start the LSP server.
--- @param extra_spawn_params? vim.lsp.rpc.ExtraSpawnParams
--- @return vim.lsp.rpc.Transport.Run
function TransportRun.new(cmd, extra_spawn_params)
  return setmetatable({
    cmd = cmd,
    extra_spawn_params = extra_spawn_params,
  }, { __index = TransportRun })
end

--- @param on_read fun(err: any, data: string)
--- @param on_exit fun(code: integer, signal: integer)
function TransportRun:listen(on_read, on_exit)
  local function on_stderr(_, chunk)
    if chunk then
      log.error('rpc', self.cmd[1], 'stderr', chunk)
    end
  end

  self.extra_spawn_params = self.extra_spawn_params or {}

  if self.extra_spawn_params.cwd then
    local stat = uv.fs_stat(self.extra_spawn_params.cwd)
    assert(stat and stat.type == 'directory' or false, 'cwd must be a directory')
  end

  -- Default to non-detached on Windows.
  local detached = vim.fn.has('win32') ~= 1
  if self.extra_spawn_params.detached ~= nil then
    detached = self.extra_spawn_params.detached
  end

  ---@type boolean, vim.SystemObj|string
  local ok, sysobj_or_err = pcall(vim.system, self.cmd, {
    stdin = true,
    stdout = on_read,
    stderr = on_stderr,
    cwd = self.extra_spawn_params.cwd,
    env = self.extra_spawn_params.env,
    detach = detached,
  }, function(obj)
    on_exit(obj.code, obj.signal)
  end)

  if not ok then ---@cast sysobj_or_err string
    local err = sysobj_or_err
    local sfx = err:match('ENOENT')
        and '. The language server is either not installed, missing from PATH, or not executable.'
      or string.format(' with error message: %s', err)

    error(('Spawning language server with cmd: `%s` failed%s'):format(vim.inspect(self.cmd), sfx))
  end ---@cast sysobj_or_err vim.SystemObj

  self.sysobj = sysobj_or_err
end

function TransportRun:write(msg)
  assert(self.sysobj):write(msg)
end

function TransportRun:is_closing()
  return self.sysobj == nil or self.sysobj:is_closing()
end

function TransportRun:terminate()
  local sysobj = assert(self.sysobj)
  if sysobj:is_closing() then
    return
  end
  sysobj:kill(15)
end

--- Transport backed by an existing `uv.uv_pipe_t` or `uv.uv_tcp_t` connection.
---
--- @class (private) vim.lsp.rpc.Transport.Connect : vim.lsp.rpc.Transport
--- @field host_or_path string
--- @field port? integer
--- @field handle? uv.uv_pipe_t|uv.uv_tcp_t
--- Connect returns a PublicClient synchronously so the caller
--- can immediately send messages before the connection is established.
--- These messages are buffered in `msgbuf`.
--- @field connected boolean
--- @field closing boolean
--- @field msgbuf vim.Ringbuf
--- @field on_exit? fun(code: integer, signal: integer)
local TransportConnect = {}

--- @param host_or_path string
--- @param port? integer
--- @return vim.lsp.rpc.Transport.Connect
function TransportConnect.new(host_or_path, port)
  return setmetatable({
    host_or_path = host_or_path,
    port = port,
    connected = false,
    -- size should be enough because the client can't really do anything until initialization is done
    -- which required a response from the server - implying the connection got established
    msgbuf = vim.ringbuf(10),
    closing = false,
  }, { __index = TransportConnect })
end

--- @param on_read fun(err: any, data: string)
--- @param on_exit? fun(code: integer, signal: integer)
function TransportConnect:listen(on_read, on_exit)
  self.on_exit = on_exit
  self.handle = (
    self.port and assert(uv.new_tcp(), 'Could not create new TCP socket')
    or assert(uv.new_pipe(false), 'Pipe could not be opened.')
  )

  local function on_connect(err)
    if err then
      local address = not self.port and self.host_or_path or (self.host_or_path .. ':' .. self.port)
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

  if not self.port then
    self.handle:connect(self.host_or_path, on_connect)
    return
  end

  local info = uv.getaddrinfo(self.host_or_path, nil)
  local resolved_host = info and info[1] and info[1].addr or self.host_or_path
  self.handle:connect(resolved_host, self.port, on_connect)
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
