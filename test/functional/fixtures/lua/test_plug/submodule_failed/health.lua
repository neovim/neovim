local M = {}

M.check = function()
  vim.health.start("report 1")
  vim.health.ok("everything is fine")
  vim.health.warn("About to add a number to nil")
  local a = nil + 2
  return a
end

return M
