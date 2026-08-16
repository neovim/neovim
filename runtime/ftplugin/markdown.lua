-- g:markdown_fenced_languages is handled by classic syntax
-- (runtime/syntax/markdown.vim), which treesitter highlighting bypasses.
if vim.g.markdown_fenced_languages == nil or vim.tbl_isempty(vim.g.markdown_fenced_languages) then
  vim.treesitter.start()

  vim.keymap.set('n', 'gO', function()
    require('vim.treesitter._headings').show_toc()
  end, { buf = 0, silent = true, desc = 'Show an Outline of the current buffer' })

  vim.keymap.set('n', ']]', function()
    require('vim.treesitter._headings').jump({ count = 1 })
  end, { buf = 0, silent = false, desc = 'Jump to next section' })
  vim.keymap.set('n', '[[', function()
    require('vim.treesitter._headings').jump({ count = -1 })
  end, { buf = 0, silent = false, desc = 'Jump to previous section' })
end

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n call v:lua.vim.treesitter.stop()'
  .. '\n sil! exe "nunmap <buffer> gO"'
  .. '\n sil! exe "nunmap <buffer> ]]" | sil! exe "nunmap <buffer> [["'
