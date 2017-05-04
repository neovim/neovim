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

local function add_idle_call(func, args)
    idle_calls[#idle_calls+1] = {func, args}
    if #idle_calls == 1 then
      idle_handle:start(run_idle_calls)
    end
end

local function cb_wait()
  local co, main = coroutine.running()
  if co == nil or main then
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
