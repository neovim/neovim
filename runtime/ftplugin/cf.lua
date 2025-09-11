local bufnr = vim.api.nvim_get_current_buf()
local filename = vim.api.nvim_buf_get_name(bufnr)

if vim.endswith(filename, '.cfc') then
  -- .cfc files use // comments
  vim.bo.commentstring = '// %s'
else
  -- .cfm and .cf files use <!--- ---> comments
  vim.bo.commentstring = '<!--- %s --->'
end

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '') .. '\n setl commentstring<'
