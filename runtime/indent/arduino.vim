" Vim indent file
" Language:	Arduino
" Maintainer:	The Vim Project <https://github.com/vim/vim>
"		Ken Takata <https://github.com/k-takata>
" Last Change:	2024 Apr 03

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

" Use C indenting.
setlocal cindent

let b:undo_indent = "setl cin<"
