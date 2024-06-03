-- These are the default option values in Vim, but not in Nvim, so must be set explicitly.
vim.bo.commentstring = '// %s'
vim.bo.define = '^\\s*#\\s*define'
vim.bo.include = '^\\s*#\\s*include'

if vim.fn.isdirectory('/usr/include') == 1 then
  vim.cmd([[
    setlocal path^=/usr/include
    setlocal path-=.
    setlocal path^=.
  ]])
end

vim.b.undo_ftplugin = vim.b.undo_ftplugin .. '|setl path<'
