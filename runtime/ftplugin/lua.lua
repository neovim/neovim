-- use treesitter over syntax
vim.treesitter.start()

vim.b.undo_ftplugin = vim.b.undo_ftplugin .. ' | call v:lua.vim.treesitter.stop()'
