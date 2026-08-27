-- Syntax highlighting for nvim.zip archive listings.

if vim.b.current_syntax then
  return
end

vim.cmd [[
  syntax match zipDirectory '.*/$'
  highlight default link zipDirectory Directory
]]

vim.b.current_syntax = 'zip'
