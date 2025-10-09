if vim.g.loaded_undotree_plugin ~= nil then
  return
end
vim.g.loaded_undotree_plugin = true

vim.api.nvim_create_user_command('Undotree', function()
  require 'undotree'.open()
end, {})
