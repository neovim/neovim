local uv = require('luv')
local mpack = require('mpack')
local uvutil = require('uvutil')

-- notify is a sentinel value used to mark message as a notification.
local notify = {}

local Nvim = {
  notify = notify
}

local Thunk = {}
Thunk.__index = Thunk
Thunk.__call = function(self, ...) return self.f(self.a, ...) end

local extension_metatables = {}

for name, ext in pairs{buf = 0, win = 1, tabpage = 2} do
  local method_prefix = name .. '_'
  local mt = {
    __index = function(self, k)
      local x = getmetatable(self)[k]
      if x ~= nil then
        return x
      end
      local f = self.nvim[method_prefix .. k]
      if f == nil then
        return nil
      end
      return setmetatable({f = f, a = self.nvim}, Thunk)
    end,
    __eq = function(self, other)
      return self.id == other.id and self.nvim == other.nvim
    end,
    __tostring = function(self)
      return name .. ' ' .. tostring(self.id)
    end
  }
  extension_metatables[ext] = mt
  -- Add constructor method. Example: Nvim:buf(id) --> buf
  Nvim[name] = function(self, id) return setmetatable({id = id, nvim = self}, mt) end
end


local Error = {}
Error.__index = Error
function Error.new(message) return setmetatable({message=message}, Error) end
function Error:__tostring() return self.message end

-- Endpoint is the MsgPack RPC endpoint.
local Endpoint = {}
Endpoint.__index = Endpoint

function Endpoint.new(w, r) --> Endpoint
  local nvim = setmetatable({
    handlers = {}
  }, Nvim)
  local ep = setmetatable({
      w = w,
      r = r,
      closed = false,
      proc = false,
    }, Endpoint)

  ep.nvim = nvim
  nvim._ep = ep

  local unpackext, packext = {}, {}
  for ext, mt in pairs(extension_metatables) do
    unpackext[ext] = function(_, s) return setmetatable({id = mpack.unpack(s), nvim = nvim}, mt) end
    packext[mt] = function(o) return ext, mpack.pack(o.id) end
  end
  ep.session = mpack.Session({unpack = mpack.Unpacker({ext = unpackext})})
  ep.pack = mpack.Packer({ext = packext})
  uv.read_start(r, function(err, chunk) return ep:on_read(err, chunk) end)

  return ep
end

function Endpoint:close()
  if self.closed then
    return
  end
  self.closed = true
  self.r:read_stop()
  local waiters = {}
  local cb
  cb, waiters[#waiters+1] = uvutil.cb_wait()
  self.w:close(cb)
  cb, waiters[#waiters+1] = uvutil.cb_wait()
  self.r:close(cb)
  if self.proc then
    cb, waiters[#waiters+1] = uvutil.cb_wait()
    self.proc:close(cb)
  end
  for _, wait in pairs(waiters) do
    wait()
  end
  self.nvim = nil
end

-- request_cb sends a message to the peer and invokes cb on completion. If the
-- last argument is the sentinel value notify, then a notification is sent.
-- Otherwise, a request is sent and cb is called (ok, reply or error).
function Endpoint:request_cb(cb, method, ...)
  local args = {...}
  if #args > 0 and args[#args] == notify then
    self.w:write(self.session:notify() .. self.pack(method) .. self.pack(table.remove(args)))
    cb()
    return
  end
  self.w:write(self.session:request(cb) .. self.pack(method) .. self.pack(args))
end

-- request_level is like request_cb, except it waits for the reply from peer.
-- If the reply is an error, then error is called with the specified level.
function Endpoint:request_level(level, method, ...) --> result
  local cb, wait = uvutil.cb_wait()
  self:request_cb(cb, method, ...)
  local ok, result = wait()
  if not ok then
    error(result, level)
  end
  return result
end

-- on_read handles data callbacks from self.r.
function Endpoint:on_read(err, chunk)
  if err then
    error(err)
  end
  if not chunk then
    self:close()
    return
  end
  local pos, len = 1, #chunk
  while pos <= len do
    local mtype, id_or_cb, method_or_error, args_or_result
    mtype, id_or_cb, method_or_error, args_or_result, pos = self.session:receive(chunk, pos)
    if mtype ~= nil then
      local f = self['on_' .. mtype]
      if not f then
        error('unknown mpack receive type: ' .. mtype)
      end
      f(self, id_or_cb, method_or_error, args_or_result)
    end
  end
end

local function errorHandler(e)
  if getmetatable(e) ~= Error then
    io.stderr:write(tostring(e), '\n', debug.traceback(), '\n')
  end
  return e
end

-- on_request handles MsgPack requests.
function Endpoint:on_request(id, method, args)
  local handler = self.nvim.handlers[method]
  if not handler then
    self.w:write(self.session:reply(id) .. self.pack("method not found") .. self.pack(mpack.NIL))
    return
  end
  uvutil.add_idle_call(coroutine.resume, {coroutine.create(function()
    local ok, result = xpcall(handler, errorHandler, unpack(args))
    local err, resp = mpack.NIL, mpack.NIL
    if ok then
      if result ~= nil then
        resp = result
      end
    else
      err = "Internal Error"
      if getmetatable(result) == Error then
        err = result.message
      end
      -- TODO: does nvim expect array in error?
      --err = {0, err}
    end
    self.w:write(self.session:reply(id) .. self.pack(err) .. self.pack(resp))
  end)})
end

-- on_notification handles MsgPack notifications.
function Endpoint:on_notification(_, method, args)
  -- TODO run notifications in a single coroutine to ensure in order execution.
  local handler = self.nvim.handlers[method]
  if not handler then
    return
  end
  uvutil.add_idle_call(coroutine.resume, {coroutine.create(function() xpcall(handler, errorHandler, unpack(args)) end)})
end

-- on_response handles MsgPack responses.
function Endpoint:on_response(cb, err, result)
  if err == mpack.NIL then
    cb(true, result)
    return
  end
  if type(err) == 'table' and #err == 2 and type(err[2]) == 'string' then
    if err[1] == 0 then
      err = "exception: " .. err[2]
    elseif err[1] == 1 then
      err =  "validation: " .. err[2]
    end
  end
  cb(false, err)
end

local function new(w, r) --> Nvim
  return Endpoint.new(w, r).nvim
end

local function new_child(cmd, args, env) --> Nvim
  local ep
  local stdin, stdout = uv.new_pipe(false), uv.new_pipe(false)
  local proc, pid = uv.spawn(cmd, {
    stdio = {stdin, stdout, 2},
    args = args,
    env = env,
  }, function()
    if ep then
      ep:close()
    end
  end)
  if not proc then
    stdin:close()
    stdout:close()
    error(pid)
  end
  ep = Endpoint.new(stdin, stdout)
  ep.proc = proc
  return ep.nvim
end

local function new_stdio() --> Nvim
  local stdin, stdout = uv.new_pipe(false), uv.new_pipe(false)
  stdin:open(0)
  stdout:open(1)
  return Endpoint.new(stdout, stdin).nvim
end

function Nvim:__index(k)
  local mt = getmetatable(self)
  local x = mt[k]
  if x ~= nil then
    return x
  end
  local method = 'nvim_' .. k
  local f = function(nvim, ...) return nvim._ep:request_level(2, method, ...) end
  mt[k] = f
  return f
end

function Nvim:close()
  self._ep:close()
end

-- request sends a message to the peer. If the last argument is the sentinel
-- value neovim.notify, then a notification is sent. Otherwise, a request is
-- sent and the reply is returned.
function Nvim:request(method, ...) --> result
  return self._ep:request_level(3, method, ...)
end

function Nvim:error(message, level)
  error(Error.new(message), level)
end

-- call calls an Nvim function and returns the result.
function Nvim:call(f, ...) --> result
  return self._ep:request_level(2, 'nvim_call_function', f, {...})
end

return {
  new = new,
  new_child = new_child,
  new_stdio = new_stdio,
  Nvim = Nvim,
  notify = notify
}
