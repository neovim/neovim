" Vim syntax file
" Language:     Nvim :checkhealth buffer
" Last Change:  2022 Nov 10

if exists("b:current_syntax")
  finish
endif

runtime! syntax/help.vim
unlet! b:current_syntax

syn case match

syn keyword healthError ERROR[:]
syn keyword healthWarning WARNING[:]
syn keyword healthSuccess OK[:]
syn match helpSectionDelim "^======*\n.*$"
syn match healthHeadingChar "=" conceal cchar=─ contained containedin=helpSectionDelim

hi def link healthError Error
hi def link healthWarning WarningMsg
hi def healthSuccess guibg=#5fff00 guifg=#080808 ctermbg=82 ctermfg=232
hi def link healthHelp Identifier

let b:current_syntax = "checkhealth"
