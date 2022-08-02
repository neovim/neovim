" Vim syntax file
" Language:     Neovim checkhealth buffer
" Last Change:  2021 Dec 15

if exists("b:current_syntax")
  finish
endif

runtime! syntax/markdown.vim
unlet! b:current_syntax

syn case match

" We do not care about markdown syntax errors
if hlexists('markdownError')
  syn clear markdownError
endif

syn keyword healthError ERROR[:] containedin=markdownCodeBlock,mkdListItemLine
syn keyword healthWarning WARNING[:] containedin=markdownCodeBlock,mkdListItemLine
syn keyword healthSuccess OK[:] containedin=markdownCodeBlock,mkdListItemLine
syn match healthHelp "|.\{-}|" containedin=markdownCodeBlock,mkdListItemLine contains=healthBar
syn match healthBar  "|" contained conceal

hi def link healthError Error
hi def link healthWarning WarningMsg
hi def healthSuccess guibg=#5fff00 guifg=#080808 ctermbg=82 ctermfg=232
hi def link healthHelp Identifier

let b:current_syntax = "checkhealth"
