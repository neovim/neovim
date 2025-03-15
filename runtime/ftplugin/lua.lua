-- use treesitter over syntax
vim.treesitter.start()

vim.bo.includeexpr = "v:lua.require'_ftplugin.lua'.includeexpr(v:fname)"

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n call v:lua.vim.treesitter.stop()'
  .. '\n setl includeexpr<'
