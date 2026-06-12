local uv = vim.uv
local strbuffer = require('vim._core.stringbuffer')

--- Interface for transport implementations.
---
--- @class (private, exact) vim.net.Transport
--- @field listen fun(self: vim.net.Transport, on_read: fun(err: any, data: string), on_exit: fun(code: integer, signal: integer))
--- @field write fun(self: vim.net.Transport, msg: string)
--- @field is_closing fun(self: vim.net.Transport): boolean
--- @field terminate fun(self: vim.net.Transport)

--- Transport backed by newly spawned process using `vim.system()`.
---
--- @class (private, exact) vim.net.TransportRun : vim.net.Transport
--- @field private cmd string[] Command to start the process.
--- @field private extra_spawn_params? vim.net.transport.ExtraSpawnParams
--- @field private log vim.Log
--- @field private sysobj? vim.SystemObj
--- @field new fun(cmd: string[], extra_spawn_params?: vim.net.transport.ExtraSpawnParams, log: vim.Log): vim.net.TransportRun
local TransportRun = {}

function TransportRun.new(cmd, extra_spawn_params, log)
  return setmetatable({
    cmd = cmd,
    extra_spawn_params = extra_spawn_params,
    log = log,
  }, { __index = TransportRun })
end

--- @param on_read fun(err: any, data: string)
--- @param on_exit fun(code: integer, signal: integer)
function TransportRun:listen(on_read, on_exit)
  local function on_stderr(_, chunk)
    if chunk then
      self.log.error('transport', self.cmd[1], 'stderr', chunk)
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
        and '. The command is either not installed, missing from PATH, or not executable.'
      or string.format(' with error message: %s', err)

    error(('Spawning process with cmd: `%s` failed%s'):format(vim.inspect(self.cmd), sfx))
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
--- @class (private, exact) vim.net.TransportConnect : vim.net.Transport
--- @field private host_or_path string
--- @field private port? integer
--- @field private log vim.Log
--- @field private handle? uv.uv_pipe_t|uv.uv_tcp_t
--- Connect returns a PublicClient synchronously so the caller
--- can immediately send messages before the connection is established.
--- These messages are buffered in `msgbuf`.
--- @field private connected boolean
--- @field private closing boolean
--- @field private msgbuf vim.Ringbuf
--- @field private on_exit? fun(code: integer, signal: integer)
--- @field new fun(host_or_path: string, port?: integer, log: vim.Log): vim.net.TransportConnect
local TransportConnect = {}

function TransportConnect.new(host_or_path, port, log)
  return setmetatable({
    host_or_path = host_or_path,
    port = port,
    log = log,
    connected = false,
    -- size should be enough because the client can't really do anything until initialization is done
    -- which required a response from the process - implying the connection got established
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
      self.log.error('Error on handle:write: %q', err)
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

--- Create a message stream from a decoder.
---
--- The decoder consumes from the given string buffer
--- and returns a message body when a full message is available.
--- `nil` means it needs more transport data.
--- decoder errors are reported through `on_error`.
---
---@class (private, exact) vim.net.MessageStream
---@field private strbuf string.buffer
---@field private decode fun(strbuf: string.buffer): string?
---@field private on_read fun(err: string?, data: string?)
---@field private on_error fun(err: any)
---@field feed fun(self: vim.net.MessageStream, err: string?, data: string?)
---@field encode fun(msg: string): string
---@field new fun(decode: (fun(strbuf: string.buffer): string?), encode: (fun(msg: string): string), on_read: fun(err: string?, data: string?), on_error: fun(err: any)): vim.net.MessageStream
local MessageStream = {}

---@param decode fun(strbuf: string.buffer): string?
---@param encode fun(msg: string): string
---@param on_read fun(err: string?, data: string?)
---@param on_error fun(err: any)
---@return vim.net.MessageStream
function MessageStream.new(decode, encode, on_read, on_error)
  return setmetatable({
    strbuf = strbuffer.new(),
    decode = decode,
    on_read = on_read,
    on_error = on_error,
    encode = encode,
  }, { __index = MessageStream })
end

---@param err string?
---@param data string?
function MessageStream:feed(err, data)
  if err then
    self.on_read(err, nil)
    return
  elseif data == nil then
    self.on_read(nil, nil)
    return
  end

  self.strbuf:put(data)

  while true do
    local ok, body = pcall(self.decode, self.strbuf)
    if not ok then
      self.on_error(body)
      return
    elseif body == nil then
      break
    end
    self.on_read(nil, body)
  end
end

return {
  TransportRun = TransportRun,
  TransportConnect = TransportConnect,
  MessageStream = MessageStream,
}
