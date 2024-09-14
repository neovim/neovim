-- uvutil is a utility for implementing cooperative multitasking using luv and
-- Lua coroutines.

local uv = require("luv")

local idle_handle = uv.new_idle()
local idle_calls = {}

local function run_idle_calls()
  local calls = idle_calls
  idle_calls = {}
  idle_handle:stop()
  for _, call in pairs(calls) do
    call[1](unpack(call[2]))
  end
end

-- add_idle_call schedules func to be called with unpack(args) at the top of
-- the IO loop.
local function add_idle_call(func, args)
    idle_calls[#idle_calls+1] = {func, args}
    if #idle_calls == 1 then
      idle_handle:start(run_idle_calls)
    end
end

-- cb_wait returns a function to invoke on the completion of an operation and a
-- function to wait on the invocation of that callback. Arguments passed to the
-- callback function are returned from the wait function.
local function cb_wait()
  local co, main = coroutine.running()
  if co == nil or main then
    -- At the top-level, the wait function runs the event loop and the callback
    -- function stops the event loop.
    local args
    return function(...)
      args = {...}
      uv.stop()
    end,
    function()
      if args == nil then
        uv.run()
      end
      return unpack(args)
    end
  else
    -- If not at the top level, the wait function yields the current coroutine
    -- and the callback resumes the coroutine.
    return function(...)
      add_idle_call(coroutine.resume, {co, ...})
    end,
    coroutine.yield
  end
end

return {
  cb_wait = cb_wait,
  add_idle_call = add_idle_call
}
