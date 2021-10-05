local M = {}
local health = require("health")

M.check = function()
  health.report_start("report 1")
  health.report_ok("everything is fine")
  health.report_warn("About to add a number to nil")
  local a = nil + 2
  return a
end

return M
