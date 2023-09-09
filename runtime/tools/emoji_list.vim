" Script to fill the window with emoji characters, one per line.
" Source this script: :source %

if &modified
  new
else
  enew
endif

lua << EOF
  local lnum = 1
  for c = 0x100, 0x1ffff do
    local cs = vim.fn.nr2char(c)
    if vim.fn.charclass(cs) == 3 then
      vim.fn.setline(lnum, '|' .. cs .. '| ' .. vim.fn.strwidth(cs))
      lnum = lnum + 1
    end
  end
EOF

set nomodified
