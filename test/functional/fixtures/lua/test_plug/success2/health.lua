local M = {}

M.check = function()
  vim.health.start('another 1')
  vim.health.ok('ok')
end

return M
