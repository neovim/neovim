---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- Async handles allow the user to "wakeup" the event loop and get a callback
--- called from another thread.
---
--- ```lua
--- local async
--- async = uv.new_async(function()
---   print("async operation ran")
---   async:close()
--- end)
---
--- async:send()
--- ```
---
---@class uv.uv_async_t : uv.uv_handle_t
---
local async = {} -- luacheck: no unused

--- Wakeup the event loop and call the async handle's callback.
---
--- **Note**: It's safe to call this function from any thread. The callback will be
--- called on the loop thread.
---
--- **Warning**: libuv will coalesce calls to `uv.async_send(async)`, that is, not
--- every call to it will yield an execution of the callback. For example: if
--- `uv.async_send()` is called 5 times in a row before the callback is called, the
--- callback will only be called once. If `uv.async_send()` is called again after
--- the callback was called, it will be called again.
---
---@param  ...        uv.threadargs
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function async:send(...) end
