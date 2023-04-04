-- Neovim indent file
-- Language:    Tree-sitter playground
-- Last Change: 2023 Apr 4

-- it's a lisp!
vim.cmd([[ runtime! indent/lisp.vim ]])

vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.b.undo_indent = vim.b.undo_indent .. '|setl et< sw<'
