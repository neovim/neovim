" Vim indent file placeholder
" Language:	Vue
" Maintainer:	None, please volunteer if you have a real Vue indent script

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif
let b:did_indent = 1

" Html comes closest
runtime! indent/html.vim
