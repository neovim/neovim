---
--- Reading/writing of msgpack over any of the stream types from `uv_stream.lua`.
--- Does not implement the RPC protocol, see `session.lua` for that.
---

local mpack = vim.mpack

local Response = {}
Response.__index = Response

function Response.new(rpc_stream, request_id)
  return setmetatable({
    _rpc_stream = rpc_stream,
    _request_id = request_id,
  }, Response)
end

function Response:send(value, is_error)
  local data = self._rpc_stream._session:reply(self._request_id)
  if is_error then
    data = data .. self._rpc_stream._pack(value)
    data = data .. self._rpc_stream._pack(mpack.NIL)
  else
    data = data .. self._rpc_stream._pack(mpack.NIL)
    data = data .. self._rpc_stream._pack(value)
  end
  self._rpc_stream._stream:write(data)
end

--- Nvim msgpack RPC stream.
---
--- @class test.RpcStream
--- @field private _stream test.Stream
--- @field private __pack table
local RpcStream = {}
RpcStream.__index = RpcStream

function RpcStream.new(stream)
  return setmetatable({
    _stream = stream,
    _pack = mpack.Packer(),
    _session = mpack.Session({
      unpack = mpack.Unpacker({
        ext = {
          -- Buffer
          [0] = function(_c, s)
            return mpack.decode(s)
          end,
          -- Window
          [1] = function(_c, s)
            return mpack.decode(s)
          end,
          -- Tabpage
          [2] = function(_c, s)
            return mpack.decode(s)
          end,
        },
      }),
    }),
  }, RpcStream)
end

function RpcStream:write(method, args, response_cb)
  local data
  if response_cb then
    assert(type(response_cb) == 'function')
    data = self._session:request(response_cb)
  else
    data = self._session:notify()
  end

  data = data .. self._pack(method) .. self._pack(args)
  self._stream:write(data)
end

function RpcStream:read_start(on_request, on_notification, on_eof)
  self._stream:read_start(function(data)
    if not data then
      return on_eof()
    end
    local type, id_or_cb, method_or_error, args_or_result
    local pos = 1
    local len = #data
    while pos <= len do
      type, id_or_cb, method_or_error, args_or_result, pos = self._session:receive(data, pos)
      if type == 'request' or type == 'notification' then
        if type == 'request' then
          on_request(method_or_error, args_or_result, Response.new(self, id_or_cb))
        else
          on_notification(method_or_error, args_or_result)
        end
      elseif type == 'response' then
        if method_or_error == mpack.NIL then
          method_or_error = nil
        else
          args_or_result = nil
        end
        id_or_cb(method_or_error, args_or_result)
      end
    end
  end)
end

function RpcStream:read_stop()
  self._stream:read_stop()
end

function RpcStream:close(signal)
  self._stream:close(signal)
end

return RpcStream
