-- Example core module
-- This file will be compiled into the nvim binary as vim._core.example

local M = {}

--- Example function
function M.hello()
  return "Hello from vim._core.example"
end

return M
