local M = {}

M.check = function()
  vim.health.report_start("report 1")
  vim.health.report_ok("everything is fine")
  vim.health.report_start("report 2")
  vim.health.report_ok("nothing to see here")
end

return M
