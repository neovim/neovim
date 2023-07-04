local uv = require('luv')

local StdioStream = {}
StdioStream.__index = StdioStream

function StdioStream.open()
  local self = setmetatable({
    _in = uv.new_pipe(false),
    _out = uv.new_pipe(false),
  }, StdioStream)
  self._in:open(0)
  self._out:open(1)
  return self
end

function StdioStream:write(data)
  self._out:write(data)
end

function StdioStream:read_start(cb)
  self._in:read_start(function(err, chunk)
    if err then
      error(err)
    end
    cb(chunk)
  end)
end

function StdioStream:read_stop()
  self._in:read_stop()
end

function StdioStream:close()
  self._in:close()
  self._out:close()
end

local SocketStream = {}
SocketStream.__index = SocketStream

function SocketStream.open(file)
  local socket = uv.new_pipe(false)
  local self = setmetatable({
    _socket = socket,
    _stream_error = nil,
  }, SocketStream)
  uv.pipe_connect(socket, file, function(err)
    self._stream_error = self._stream_error or err
  end)
  return self
end

function SocketStream.connect(host, port)
  local socket = uv.new_tcp()
  local self = setmetatable({
    _socket = socket,
    _stream_error = nil,
  }, SocketStream)
  uv.tcp_connect(socket, host, port, function(err)
    self._stream_error = self._stream_error or err
  end)
  return self
end

function SocketStream:write(data)
  if self._stream_error then
    error(self._stream_error)
  end
  uv.write(self._socket, data, function(err)
    if err then
      error(self._stream_error or err)
    end
  end)
end

function SocketStream:read_start(cb)
  if self._stream_error then
    error(self._stream_error)
  end
  uv.read_start(self._socket, function(err, chunk)
    if err then
      error(err)
    end
    cb(chunk)
  end)
end

function SocketStream:read_stop()
  if self._stream_error then
    error(self._stream_error)
  end
  uv.read_stop(self._socket)
end

function SocketStream:close()
  uv.close(self._socket)
end

local ChildProcessStream = {}
ChildProcessStream.__index = ChildProcessStream

function ChildProcessStream.spawn(argv, env, io_extra)
  local self = setmetatable({
    _child_stdin = uv.new_pipe(false),
    _child_stdout = uv.new_pipe(false),
    _exiting = false,
  }, ChildProcessStream)
  local prog = argv[1]
  local args = {}
  for i = 2, #argv do
    args[#args + 1] = argv[i]
  end
  self._proc, self._pid = uv.spawn(prog, {
    stdio = { self._child_stdin, self._child_stdout, 2, io_extra },
    args = args,
    env = env,
  }, function(status, signal)
    self.status = status
    self.signal = signal
  end)

  if not self._proc then
    local err = self._pid
    error(err)
  end

  return self
end

function ChildProcessStream:write(data)
  self._child_stdin:write(data)
end

function ChildProcessStream:read_start(cb)
  self._child_stdout:read_start(function(err, chunk)
    if err then
      error(err)
    end
    cb(chunk)
  end)
end

function ChildProcessStream:read_stop()
  self._child_stdout:read_stop()
end

function ChildProcessStream:close(signal)
  if self._closed then
    return
  end
  self._closed = true
  self:read_stop()
  self._child_stdin:close()
  self._child_stdout:close()
  if type(signal) == 'string' then
    self._proc:kill('sig' .. signal)
  end
  while self.status == nil do
    uv.run('once')
  end
  return self.status, self.signal
end

return {
  StdioStream = StdioStream,
  ChildProcessStream = ChildProcessStream,
  SocketStream = SocketStream,
}
