local M = {}

M.check = function()
  vim.health.start('nested lua/ directory')
  vim.health.ok('everything is ok')
end

return M
