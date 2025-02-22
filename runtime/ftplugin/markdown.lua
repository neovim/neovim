vim.keymap.set('n', 'gO', function()
  require('vim.treesitter._headings').show_toc()
end, { buffer = 0, silent = true, desc = 'Show table of contents for current buffer' })

vim.keymap.set('n', ']]', function()
  require('vim.treesitter._headings').jump({ count = 1 })
end, { buffer = 0, silent = false, desc = 'Jump to next section' })
vim.keymap.set('n', '[[', function()
  require('vim.treesitter._headings').jump({ count = -1 })
end, { buffer = 0, silent = false, desc = 'Jump to previous section' })

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n sil! exe "nunmap <buffer> gO"'
  .. '\n sil! exe "nunmap <buffer> ]]" | sil! exe "nunmap <buffer> [["'
