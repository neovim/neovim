-- use treesitter over syntax (for highlighted code blocks)
vim.treesitter.start()

-- Add custom highlights for list in `:h highlight-groups`.
local bufname = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
if vim.endswith(bufname, '/doc/syntax.txt') then
  require('vim.vimhelp').highlight_groups({
    { start = [[\*group-name\*]], stop = '^======', match = '^(%w+)\t' },
    { start = [[\*highlight-groups\*]], stop = '^======', match = '^(%w+)\t' },
  })
elseif vim.endswith(bufname, '/doc/treesitter.txt') then
  require('vim.vimhelp').highlight_groups({
    {
      start = [[\*treesitter-highlight-groups\*]],
      stop = [[\*treesitter-highlight-spell\*]],
      match = '^@[%w%p]+',
    },
  })
elseif vim.endswith(bufname, '/doc/diagnostic.txt') then
  require('vim.vimhelp').highlight_groups({
    { start = [[\*diagnostic-highlights\*]], stop = '^======', match = '^(%w+)' },
  })
elseif vim.endswith(bufname, '/doc/lsp.txt') then
  require('vim.vimhelp').highlight_groups({
    { start = [[\*lsp-highlight\*]], stop = '^------', match = '^(%w+)' },
    { start = [[\*lsp-semantic-highlight\*]], stop = '^======', match = '^@[%w%p]+' },
  })
end

vim.keymap.set('n', 'gO', function()
  require('vim.vimhelp').show_toc()
end, { buffer = 0, silent = true })

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '') .. '\n exe "nunmap <buffer> gO"'
vim.b.undo_ftplugin = vim.b.undo_ftplugin .. ' | call v:lua.vim.treesitter.stop()'
