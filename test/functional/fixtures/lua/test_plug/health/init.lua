local M = {}

M.check = function()
  vim.health.start('report 1')
  vim.health.ok('everything is fine')
  vim.health.start('report 2')
  vim.health.ok('nothing to see here')
end

return M
