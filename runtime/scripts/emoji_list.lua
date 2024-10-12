-- Script to fill the window with emoji characters, one per line.
-- Source this script: :source %

if vim.bo.modified then
  vim.cmd.new()
else
  vim.cmd.enew()
end

local lnum = 1
for c = 0x100, 0x1ffff do
  local cs = vim.fn.nr2char(c)
  if vim.fn.charclass(cs) == 3 then
    vim.fn.setline(lnum, string.format('|%s| %d', cs, vim.fn.strwidth(cs)))
    lnum = lnum + 1
  end
end

vim.bo.modified = false
