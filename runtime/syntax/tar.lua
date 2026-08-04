-- Syntax highlighting for nvim.tar archive listings.

if vim.b.current_syntax then
  return
end

vim.cmd [[
  syntax match tarDirectory '.*/$'
  highlight default link tarDirectory Directory
]]

vim.b.current_syntax = 'tar'
