" Nvim syntax file
" Language:     EditorConfig
" Last Change:  2023-07-20
"
" This file is intentionally _not_ copied from Vim.

runtime! syntax/dosini.vim
unlet! b:current_syntax

syntax match editorconfigUnknownProperty "^\s*\zs[a-zA-Z0-9_-]\+\ze\s*="
syntax keyword editorconfigProperty root

lua<<
local props = {}
for k in pairs(require('editorconfig').properties) do
  props[#props + 1] = k
end
vim.cmd(string.format('syntax keyword editorconfigProperty %s', table.concat(props, ' ')))
.

hi def link editorconfigProperty dosiniLabel

let b:current_syntax = 'editorconfig'
