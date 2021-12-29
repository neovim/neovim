" Vim syntax file
" Language:	bash
" Maintainer:	Bram
" Last Change:	2019 Sep 27

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" The actual syntax is in sh.vim and controlled by buffer-local variables.
unlet! b:is_sh
unlet! b:is_kornshell
let b:is_bash = 1

runtime! syntax/sh.vim

let b:current_syntax = 'bash'

" vim: ts=8
