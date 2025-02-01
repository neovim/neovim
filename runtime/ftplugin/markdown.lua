vim.keymap.set('n', 'gO', function()
  require('_textutils').show_toc()
end, { buffer = 0, silent = true, desc = 'Show table of contents for current buffer' })

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '') .. '\n exe "nunmap <buffer> gO"'
