" Vim indent file
" Language:             dict(1) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Last Change:      	2022 Apr 06

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentkeys=0{,0},!^F,o,O cinwords= autoindent smartindent
setlocal nosmartindent
inoremap <buffer> # X#

let b:undo_indent = "setl ai< cinw< indk< si< | silent! iunmap <buffer> #"
