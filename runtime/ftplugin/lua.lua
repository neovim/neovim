-- use treesitter over syntax
vim.treesitter.start()

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '') .. '\n call v:lua.vim.treesitter.stop()'
