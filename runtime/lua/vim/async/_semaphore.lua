-- LuaLS cannot model the generic annotations used by this vendored implementation.
---@diagnostic disable: no-unknown, undefined-doc-name, luadoc-miss-symbol, missing-return, missing-return-value, param-type-mismatch, return-type-mismatch, redundant-return-value, undefined-field, need-check-nil, await-in-sync

local util = require('vim.async._util')
local new_event = require('vim.async._event')

local pcall = pcall
do
  local ok, coxpcall = pcall(require, 'coxpcall')
  if ok and type(coxpcall) == 'table' and type(coxpcall.pcall) == 'function' then
    pcall = coxpcall.pcall
  end
end
local validate = vim.validate

--- A semaphore manages an internal permit counter. [Semaphore:acquire()]
--- consumes one permit and [Semaphore:release()] returns one permit. If no
--- permits are available, `acquire()` suspends the current task until another
--- task releases one.
---
--- The preferred way to use a Semaphore is with the `with()` method, which
--- automatically acquires and releases the semaphore around a function call.
--- This is useful for limiting sections that start external work and then
--- await it, such as file reads, requests, or subprocesses.
---
--- ```lua
--- local async = vim.async
---
--- async.run(function()
---   local limit = async.semaphore(4)
---   local tasks = {}
---
---   for _, path in ipairs(paths) do
---     table.insert(tasks, async.run(function()
---       return limit:with(function()
---         return read_file(path)
---       end)
---     end))
---   end
---
---   local next_task = async.iter(tasks)
---   while true do
---     local task = next_task()
---     if task == nil then
---       break
---     end
---     async.await(task)
---   end
--- end)
--- ```
--- @class vim.async.Semaphore
--- @field private _permits integer
--- @field private _max_permits integer
--- @field package _event vim.async.Event
local Semaphore = {}
Semaphore.__index = Semaphore

--- Executes a function while holding one semaphore permit.
---
--- This acquires the semaphore before running the function and releases it
--- after the function completes, even if it errors or the current task is
--- closed.
--- @async
--- @generic R
--- @param fn async fun(): R... # Function to execute within the semaphore's context.
--- @return R... # Result(s) of the executed function.
function Semaphore:with(fn)
  self:acquire()
  -- This pcall is only a try/finally guard for release(); all errors are
  -- immediately rethrown so it is not an async recovery boundary.
  local r = util.pack_len(pcall(fn))
  self:release()
  local stat = r[1]
  if not stat then
    local err = r[2]
    error(err, 0)
  end
  return util.unpack_len(r, 2)
end

--- Acquire a semaphore permit.
---
--- If the internal counter is greater than zero, decrement it by `1` and
--- return immediately. If it is `0`, wait until [Semaphore:release()] is
--- called.
--- @async
function Semaphore:acquire()
  self._event:wait()
  self._permits = self._permits - 1
  assert(self._permits >= 0, 'Semaphore value is negative')
  if self._permits == 0 then
    self._event:clear()
  end
end

--- Release a semaphore permit.
---
--- Increments the internal counter by `1` and can wake a task waiting in
--- [Semaphore:acquire()].
---
--- Calling this more times than permits were acquired raises an error.
function Semaphore:release()
  if self._permits >= self._max_permits then
    error('Semaphore value is greater than max permits', 2)
  end
  self._permits = self._permits + 1
  self._event:set(1)
end

--- Create an async semaphore that allows up to a given number of acquisitions.
---
--- Prefer [Semaphore:with()] for most uses so permits are released reliably.
--- Use [Semaphore:acquire()] and [Semaphore:release()] directly only when the
--- acquire and release points cannot be expressed as one function call.
--- @param permits? integer (default: 1)
--- @return vim.async.Semaphore
local function new_semaphore(permits)
  validate('permits', permits, 'number', true)
  permits = permits or 1
  if permits < 1 or permits % 1 ~= 0 then
    error('permits: expected positive integer', 2)
  end

  local obj = setmetatable({
    _max_permits = permits,
    _permits = permits,
    _event = new_event(),
  }, Semaphore)
  obj._event:set()
  return obj
end

return new_semaphore
