local M = {}

M.check = function()
  vim.health.report_start("report 1")
  vim.health.report_ok("everything is fine")
  vim.health.report_warn("About to add a number to nil")
  local a = nil + 2
  return a
end

return M
