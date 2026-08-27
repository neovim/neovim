vim.wo[0][0].wrap = true
vim.wo[0][0].breakindent = true
vim.wo[0][0].linebreak = true
vim.wo[0][0].list = false
vim.wo[0][0].conceallevel = 2
vim.wo[0][0].concealcursor = 'nc'
vim.bo.iskeyword = '!-~,^*,^|,^",192-255'

vim.keymap.set('n', 'gO', function()
  require('vim.treesitter._headings').show_toc(6)
end, { buf = 0, silent = true, desc = 'Show an Outline of the current buffer' })

vim.keymap.set('n', ']]', function()
  require('vim.treesitter._headings').jump({ count = 1, level = 1 })
end, { buf = 0, silent = false, desc = 'Jump to next section' })
vim.keymap.set('n', '[[', function()
  require('vim.treesitter._headings').jump({ count = -1, level = 1 })
end, { buf = 0, silent = false, desc = 'Jump to previous section' })

-- Look for tags in help tags files
vim.bo.tags = vim
  .iter(vim.api.nvim_get_runtime_file('doc/tags doc/tags-??', true))
  :map(vim.fn.fnameescape)
  :map(function(path)
    return vim.fn.escape(path, ',')
  end)
  :join(',')

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n sil! exe "nunmap <buffer> gO"'
  .. '\n sil! exe "nunmap <buffer> ]]" | sil! exe "nunmap <buffer> [["'
  .. '\n setlocal wrap< breakindent< linebreak< list< conceallevel< concealcursor< iskeyword< tags<'
