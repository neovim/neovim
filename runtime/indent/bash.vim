" Vim indent file
" Language:	bash
" Maintainer:	Bram
" Last Change:	2019 Sep 27

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif

" The actual indenting is in sh.vim and controlled by buffer-local variables.
unlet! b:is_sh
unlet! b:is_kornshell
let b:is_bash = 1

runtime! indent/sh.vim

" vim: ts=8
