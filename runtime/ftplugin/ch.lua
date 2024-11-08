vim.bo.commentstring = '// %s'

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '') .. '\n setl commentstring<'
