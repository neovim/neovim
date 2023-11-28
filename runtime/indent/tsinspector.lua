-- Neovim indent file
-- Language:    Tree-sitter inspector
-- Last Change: 2023 Nov 28

-- Only load this indent file when no other was loaded
if vim.b.did_indent then
  return
end
vim.b.did_indent = 1

vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.b.undo_indent = 'setl et< sw<'
