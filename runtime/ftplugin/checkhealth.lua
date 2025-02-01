vim.keymap.set('n', 'gO', function()
  require('_textutils').show_toc()
end, { buffer = 0, silent = true, desc = 'Show table of contents for current buffer' })

vim.keymap.set('n', ']]', function()
  require('_textutils').jump({ count = 1, level = 1 })
end, { buffer = 0, silent = false, desc = 'Jump to next section' })
vim.keymap.set('n', '[[', function()
  require('_textutils').jump({ count = -1, level = 1 })
end, { buffer = 0, silent = false, desc = 'Jump to previous section' })

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n exe "nunmap <buffer> gO"'
  .. '\n exe "nunmap <buffer> ]]" | exe "nunmap <buffer> [["'
