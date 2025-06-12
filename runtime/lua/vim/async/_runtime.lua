-- LuaLS cannot model the generic annotations used by this vendored implementation.
---@diagnostic disable: no-unknown, undefined-doc-name, luadoc-miss-symbol, missing-return, missing-return-value, param-type-mismatch, return-type-mismatch, redundant-return-value, undefined-field, need-check-nil, await-in-sync

local validate = vim.validate

--- @class vim.async.Timer: vim.async.Closable
--- @nodoc
--- @field start fun(self, timeout: integer, repeat_interval: integer, callback: fun())

--- @alias vim.async.TimerFactory fun(): vim.async.Timer
--- @nodoc

--- @class vim.async.ConfigOpts
--- @nodoc
--- @field wait? fun(timeout: integer, predicate: fun(): boolean): boolean Run the event loop until the predicate succeeds or the timeout expires.
--- @field schedule? fun(callback: fun()) Run a callback on the next event loop turn.
--- @field new_timer? vim.async.TimerFactory Create libuv-compatible timers for `sleep()` and `timeout()`.
--- @field debug? boolean Capture task creation metadata for debugging.

--- @class vim.async.Runtime
--- @nodoc
--- @field wait fun(timeout: integer, predicate: fun(): boolean): boolean
--- @field schedule fun(callback: fun())
--- @field new_timer vim.async.TimerFactory
--- @field debug boolean
local M = {}
M.debug = false

--- @nodoc
--- @param opts vim.async.ConfigOpts
function M.config(opts)
  validate('opts', opts, 'table')
  validate('opts.wait', opts.wait, 'callable', true)
  validate('opts.schedule', opts.schedule, 'callable', true)
  validate('opts.new_timer', opts.new_timer, 'callable', true)
  validate('opts.debug', opts.debug, 'boolean', true)

  M.wait = opts.wait or M.wait
  M.schedule = opts.schedule or M.schedule
  M.new_timer = opts.new_timer or M.new_timer
  if opts.debug ~= nil then
    M.debug = opts.debug
  end
end

return M
