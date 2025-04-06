---
--- Nvim msgpack-RPC protocol session. Manages requests/notifications/responses.
---

local uv = vim.uv
local RpcStream = require('test.client.rpc_stream')

--- Nvim msgpack-RPC protocol session. Manages requests/notifications/responses.
---
--- @class test.Session
--- @field private _pending_messages string[] Requests/notifications received from the remote end.
--- @field private _rpc_stream test.RpcStream
--- @field private _prepare uv.uv_prepare_t
--- @field private _timer uv.uv_timer_t
--- @field private _is_running boolean true during `Session:run()` scope.
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

--- Creates a new msgpack-RPC session.
function Session.new(stream)
  return setmetatable({
    _rpc_stream = RpcStream.new(stream),
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

--- Sends a notification to the RPC endpoint.
function Session:notify(method, ...)
  self._rpc_stream:write(method, { ... })
end

--- Sends a request to the RPC endpoint.
---
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

--- Processes incoming RPC requests/notifications until exhausted.
---
--- TODO(justinmk): luaclient2 avoids this via uvutil.cb_wait() + uvutil.add_idle_call()?
---
--- @param request_cb function Handles requests from the sever to the local end.
--- @param notification_cb function Handles notifications from the sever to the local end.
--- @param setup_cb function
--- @param timeout number
function Session:run(request_cb, notification_cb, setup_cb, timeout)
  --- Handles an incoming request.
  local function on_request(method, args, response)
    coroutine_exec(request_cb, method, args, function(status, result, flag)
      if status then
        response:send(result, flag)
      else
        response:send(result, true)
      end
    end)
  end

  --- Handles an incoming notification.
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
  self._rpc_stream:close(signal)
  self.closed = true
end

--- Sends a request to the RPC endpoint, without blocking (schedules a coroutine).
function Session:_yielding_request(method, args)
  return coroutine.yield(function(co)
    self._rpc_stream:write(method, args, function(err, result)
      resume(co, err, result)
    end)
  end)
end

--- Sends a request to the RPC endpoint, and blocks (polls event loop) until a response is received.
function Session:_blocking_request(method, args)
  local err, result

  -- Invoked when a request is received from the remote end.
  local function on_request(method_, args_, response)
    table.insert(self._pending_messages, { 'request', method_, args_, response })
  end

  -- Invoked when a notification is received from the remote end.
  local function on_notification(method_, args_)
    table.insert(self._pending_messages, { 'notification', method_, args_ })
  end

  self._rpc_stream:write(method, args, function(e, r)
    err = e
    result = r
    uv.stop()
  end)

  -- Poll for incoming requests/notifications received from the remote end.
  self:_run(on_request, on_notification)
  return (err or self.eof_err), result
end

--- Polls for incoming requests/notifications received from the remote end.
function Session:_run(request_cb, notification_cb, timeout)
  if type(timeout) == 'number' then
    self._prepare:start(function()
      self._timer:start(timeout, 0, function()
        uv.stop()
      end)
      self._prepare:stop()
    end)
  end
  self._rpc_stream:read_start(request_cb, notification_cb, function()
    uv.stop()

    --- @diagnostic disable-next-line: invisible
    local stderr = self._rpc_stream._stream.stderr --[[@as string?]]
    -- See if `ProcStream.stderr` has anything useful.
    stderr = '' ~= ((stderr or ''):match('^%s*(.*%S)') or '') and ' stderr:\n' .. stderr or ''

    self.eof_err = { 1, 'EOF was received from Nvim. Likely the Nvim process crashed.' .. stderr }
  end)
  uv.run()
  self._prepare:stop()
  self._timer:stop()
  self._rpc_stream:read_stop()
end

--- Nvim msgpack-RPC session.
return Session
