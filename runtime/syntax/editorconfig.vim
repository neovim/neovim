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
local props = vim.tbl_keys(require('editorconfig').properties)
vim.cmd.syntax { 'keyword', 'editorconfigProperty', unpack(props) }
.

hi def link editorconfigProperty dosiniLabel

let b:current_syntax = 'editorconfig'
