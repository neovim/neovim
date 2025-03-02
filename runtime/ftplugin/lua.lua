-- use treesitter over syntax
vim.treesitter.start()

vim.bo.omnifunc = 'v:lua.vim.lua_omnifunc'

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n call v:lua.vim.treesitter.stop() \n setl omnifunc<'
