local M = {}
local health = require("health")

M.check = function()
  health.report_start("report 1")
  health.report_ok("everything is fine")
  health.report_start("report 2")
  health.report_ok("nothing to see here")
end

return M
