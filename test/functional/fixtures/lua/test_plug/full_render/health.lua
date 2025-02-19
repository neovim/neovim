local M = {}

M.check = function()
  vim.health.start('report 1')
  vim.health.ok('life is fine')
  vim.health.warn('no what installed', { 'pip what', 'make what' })
  vim.health.start('report 2')
  vim.health.info('stuff is stable')
  vim.health.error('why no hardcopy', { ':h :hardcopy', ':h :TOhtml' })
end

return M
