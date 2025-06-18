---@alias vim.ui.img._promise.Status 'ok'|'fail'|'waiting'

---Utility class to support async and sync handling of success and failure.
---@class vim.ui.img._Promise<T>:{context:(fun(self:vim.ui.img._Promise<T>):(string|nil)),status:(fun(self:vim.ui.img._Promise<T>):vim.ui.img._promise.Status),ok:(fun(self:vim.ui.img._Promise<T>,value:T):vim.ui.img._Promise<T>),fail:(fun(self:vim.ui.img._Promise<T>,err:string|nil):vim.ui.img._Promise<T>),on_done:(fun(self:vim.ui.img._Promise<T>,f:fun(err:string|nil,value:T|nil)):vim.ui.img._Promise<T>),on_ok:(fun(self:vim.ui.img._Promise<T>,f:fun(value:T)):vim.ui.img._Promise<T>),on_fail:(fun(self:vim.ui.img._Promise<T>,f:fun(err:string)):vim.ui.img._Promise<T>),wait:(fun(self:vim.ui.img._Promise<T>,opts?:{timeout?:integer,interval?:integer}):(T|nil,string|nil))}
---@field private __allow_nil? boolean
---@field private __context? string
---@field private __on_done fun(err:string|nil, value:any)[]
---@field private __on_fail fun(err:string)[]
---@field private __on_ok fun(value:any)[]
---@field private __status vim.ui.img._promise.Status
---@field private __value any
local M = {}
M.__index = M

---Creates a promise of some value in the future.
---@param opts? {allow_nil?:boolean, context?:string}
---@return vim.ui.img._Promise
function M.new(opts)
  opts = opts or {}

  local instance = {}
  setmetatable(instance, M)

  instance.__allow_nil = opts.allow_nil
  instance.__context = opts.context
  instance.__on_done = {}
  instance.__on_fail = {}
  instance.__on_ok = {}
  instance.__status = 'waiting'

  return instance
end

---Returns the context associated with the promise, if any.
---@return string|nil
function M:context()
  return self.__context
end

---Returns the status of the promise.
---@return vim.ui.img._promise.Status
function M:status()
  return self.__status
end

---Completes the promise by marking it as successful.
---If the promise is already complete, will throw an error.
---@param value any
---@return vim.ui.img._Promise
function M:ok(value)
  assert(self.__status == 'waiting', 'promise already complete')
  assert(self.__allow_nil or value ~= nil, 'value cannot be nil')
  self.__value = value
  self.__status = 'ok'

  local on_ok = self.__on_ok
  self.__on_ok = {}

  vim.schedule(function()
    for _, f in ipairs(on_ok) do
      pcall(f, value)
    end
  end)

  local on_done = self.__on_done
  self.__on_done = {}

  vim.schedule(function()
    for _, f in ipairs(on_done) do
      pcall(f, nil, value)
    end
  end)

  return self
end

---Completes the promise by marking it as failed.
---A nil value for `err` will insert a default error message.
---If the promise is already complete, will throw an error.
---@param err string|nil
---@return vim.ui.img._Promise
function M:fail(err)
  assert(self.__status == 'waiting', 'promise already complete')
  vim.validate('err', err, 'string', true)

  err = err or 'failed'
  self.__value = err
  self.__status = 'fail'

  local on_fail = self.__on_fail
  self.__on_fail = {}

  vim.schedule(function()
    for _, f in ipairs(on_fail) do
      pcall(f, err)
    end
  end)

  local on_done = self.__on_done
  self.__on_done = {}

  vim.schedule(function()
    for _, f in ipairs(on_done) do
      pcall(f, err, nil)
    end
  end)

  return self
end

---Invokes `f` once the promise has concluded, passing in either an
---error or a value depending on whether or not the promise succeeded.
---
---A nil value for `f` will be ignored.
---@param f fun(err:string|nil, value:any)|nil
---@return vim.ui.img._Promise
function M:on_done(f)
  if type(f) == 'function' then
    if self.__status == 'waiting' then
      table.insert(self.__on_done, f)
    elseif self.__status == 'ok' then
      vim.schedule(function()
        f(nil, self.__value)
      end)
    elseif self.__status == 'fail' then
      vim.schedule(function()
        f(self.__value, nil)
      end)
    end
  end
  return self
end

---Invokes `f` once the promise has succeeded, passing
---in the value tied to the success.
---
---A nil value for `f` will be ignored.
---@param f fun(value:any)|nil
---@return vim.ui.img._Promise
function M:on_ok(f)
  if type(f) == 'function' then
    if self.__status == 'waiting' then
      table.insert(self.__on_ok, f)
    elseif self.__status == 'ok' then
      vim.schedule(function()
        f(self.__value)
      end)
    end
  end
  return self
end

---Invokes `f` once the promise has failed, passing
---in the error tied to the failure.
---
---A nil value for `f` will be ignored.
---@param f fun(err:string)|nil
---@return vim.ui.img._Promise
function M:on_fail(f)
  if type(f) == 'function' then
    if self.__status == 'waiting' then
      table.insert(self.__on_fail, f)
    elseif self.__status == 'fail' then
      vim.schedule(function()
        f(self.__value)
      end)
    end
  end
  return self
end

---Waits `timeout` milliseconds (default 1000) for the promise to complete.
---Checks every `interval` milliseconds (default 200).
---@param opts? {timeout?:integer, interval?:integer}
---@return any value, string|nil err
function M:wait(opts)
  opts = opts or {}

  local context = self.__context
  local timeout = opts.timeout or 1000
  local interval = opts.interval or 200

  local _, status = vim.wait(timeout, function()
    return self.__status ~= 'waiting'
  end, interval)

  if self.__status == 'ok' then
    return self.__value, nil
  elseif self.__status == 'fail' then
    return nil, self.__value
  elseif status == -1 then
    local msg = 'timeout reached'
    if context then
      msg = string.format('%s (%s)', context, msg)
    end
    return nil, msg
  elseif status == -2 then
    local msg = 'interrupted'
    if context then
      msg = string.format('%s (%s)', context, msg)
    end
    return nil, msg
  end
end

return M
