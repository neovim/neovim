-- use treesitter over syntax
if not vim.fn.get(vim.g, 'vim_no_treesitter', 0) then
  vim.treesitter.start()
end

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '') .. '\n call v:lua.vim.treesitter.stop()'
