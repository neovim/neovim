" Vim indent file
" Language:             dictd(8) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-12-20

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentkeys=0{,0},!^F,o,O cinwords= autoindent smartindent
setlocal nosmartindent
inoremap <buffer> # X#
