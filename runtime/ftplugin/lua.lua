-- use treesitter over syntax
vim.treesitter.start()

vim.bo.includeexpr = [[v:lua.require'vim._ftplugin.lua'.includeexpr(v:fname)]]
vim.bo.omnifunc = 'v:lua.vim.lua_omnifunc'
vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.wo[0][0].foldmethod = 'expr'

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n call v:lua.vim.treesitter.stop()'
  .. '\n setl omnifunc< foldexpr< foldmethod< includeexpr<'
