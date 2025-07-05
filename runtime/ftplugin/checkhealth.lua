vim.keymap.set('n', 'gO', function()
  local win = vim.api.nvim_get_current_win()
  vim.wo[win].eventignorewin = 'BufEnter'
  require('vim.treesitter._headings').show_toc()
  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    local curwin = vim.api.nvim_get_current_win()
    if curwin ~= win then
      local cfg = vim.api.nvim_win_get_config(win)
      local qfheight = vim.api.nvim_win_get_height(curwin)
      if vim.o.lines - cfg.row - cfg.height < qfheight then
        cfg.height = cfg.height - vim.api.nvim_win_get_height(curwin)
        vim.api.nvim_win_set_config(win, cfg)
      end
    end
    vim.wo[win].eventignorewin = ''
  end)
end, { buffer = 0, silent = true, desc = 'Show an Outline of the current buffer' })

vim.keymap.set('n', ']]', function()
  require('vim.treesitter._headings').jump({ count = 1, level = 1 })
end, { buffer = 0, silent = false, desc = 'Jump to next section' })
vim.keymap.set('n', '[[', function()
  require('vim.treesitter._headings').jump({ count = -1, level = 1 })
end, { buffer = 0, silent = false, desc = 'Jump to previous section' })

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n sil! exe "nunmap <buffer> gO"'
  .. '\n sil! exe "nunmap <buffer> ]]" | sil! exe "nunmap <buffer> [["'
