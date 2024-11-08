local uv = vim.uv
local MsgpackRpcStream = require('test.client.msgpack_rpc_stream')

--- @class test.Session
--- @field private _pending_messages string[]
--- @field private _msgpack_rpc_stream test.MsgpackRpcStream
--- @field private _prepare uv.uv_prepare_t
--- @field private _timer uv.uv_timer_t
--- @field private _is_running boolean
--- @field exec_lua_setup boolean
local Session = {}
Session.__index = Session
if package.loaded['jit'] then
  -- luajit pcall is already coroutine safe
  Session.safe_pcall = pcall
else
  Session.safe_pcall = require 'coxpcall'.pcall
end

local function resume(co, ...)
  local status, result = coroutine.resume(co, ...)

  if coroutine.status(co) == 'dead' then
    if not status then
      error(result)
    end
    return
  end

  assert(coroutine.status(co) == 'suspended')
  result(co)
end

local function coroutine_exec(func, ...)
  local args = { ... }
  local on_complete --- @type function?

  if #args > 0 and type(args[#args]) == 'function' then
    -- completion callback
    on_complete = table.remove(args)
  end

  resume(coroutine.create(function()
    local status, result, flag = Session.safe_pcall(func, unpack(args))
    if on_complete then
      coroutine.yield(function()
        -- run the completion callback on the main thread
        on_complete(status, result, flag)
      end)
    end
  end))
end

function Session.new(stream)
  return setmetatable({
    _msgpack_rpc_stream = MsgpackRpcStream.new(stream),
    _pending_messages = {},
    _prepare = uv.new_prepare(),
    _timer = uv.new_timer(),
    _is_running = false,
  }, Session)
end

--- @param timeout integer?
--- @return string?
function Session:next_message(timeout)
  local function on_request(method, args, response)
    table.insert(self._pending_messages, { 'request', method, args, response })
    uv.stop()
  end

  local function on_notification(method, args)
    table.insert(self._pending_messages, { 'notification', method, args })
    uv.stop()
  end

  if self._is_running then
    error('Event loop already running')
  end

  if #self._pending_messages > 0 then
    return table.remove(self._pending_messages, 1)
  end

  -- if closed, only return pending messages
  if self.closed then
    return nil
  end

  self:_run(on_request, on_notification, timeout)
  return table.remove(self._pending_messages, 1)
end

function Session:notify(method, ...)
  self._msgpack_rpc_stream:write(method, { ... })
end

--- @param method string
--- @param ... any
--- @return boolean, table
function Session:request(method, ...)
  local args = { ... }
  local err, result
  if self._is_running then
    err, result = self:_yielding_request(method, args)
  else
    err, result = self:_blocking_request(method, args)
  end

  if err then
    return false, err
  end

  return true, result
end

--- Runs the event loop.
function Session:run(request_cb, notification_cb, setup_cb, timeout)
  local function on_request(method, args, response)
    coroutine_exec(request_cb, method, args, function(status, result, flag)
      if status then
        response:send(result, flag)
      else
        response:send(result, true)
      end
    end)
  end

  local function on_notification(method, args)
    coroutine_exec(notification_cb, method, args)
  end

  self._is_running = true

  if setup_cb then
    coroutine_exec(setup_cb)
  end

  while #self._pending_messages > 0 do
    local msg = table.remove(self._pending_messages, 1)
    if msg[1] == 'request' then
      on_request(msg[2], msg[3], msg[4])
    else
      on_notification(msg[2], msg[3])
    end
  end

  self:_run(on_request, on_notification, timeout)
  self._is_running = false
end

function Session:stop()
  uv.stop()
end

function Session:close(signal)
  if not self._timer:is_closing() then
    self._timer:close()
  end
  if not self._prepare:is_closing() then
    self._prepare:close()
  end
  self._msgpack_rpc_stream:close(signal)
  self.closed = true
end

function Session:_yielding_request(method, args)
  return coroutine.yield(function(co)
    self._msgpack_rpc_stream:write(method, args, function(err, result)
      resume(co, err, result)
    end)
  end)
end

function Session:_blocking_request(method, args)
  local err, result

  local function on_request(method_, args_, response)
    table.insert(self._pending_messages, { 'request', method_, args_, response })
  end

  local function on_notification(method_, args_)
    table.insert(self._pending_messages, { 'notification', method_, args_ })
  end

  self._msgpack_rpc_stream:write(method, args, function(e, r)
    err = e
    result = r
    uv.stop()
  end)

  self:_run(on_request, on_notification)
  return (err or self.eof_err), result
end

function Session:_run(request_cb, notification_cb, timeout)
  if type(timeout) == 'number' then
    self._prepare:start(function()
      self._timer:start(timeout, 0, function()
        uv.stop()
      end)
      self._prepare:stop()
    end)
  end
  self._msgpack_rpc_stream:read_start(request_cb, notification_cb, function()
    uv.stop()
    self.eof_err = { 1, 'EOF was received from Nvim. Likely the Nvim process crashed.' }
  end)
  uv.run()
  self._prepare:stop()
  self._timer:stop()
  self._msgpack_rpc_stream:read_stop()
end

return Session
