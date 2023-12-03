-- use treesitter over syntax (for highlighted code blocks)
vim.treesitter.start()

-- add custom highlights for list in `:h highlight-groups`
if vim.endswith(vim.fs.normalize(vim.api.nvim_buf_get_name(0)), '/doc/syntax.txt') then
  require('vim.vimhelp').highlight_groups()
end
