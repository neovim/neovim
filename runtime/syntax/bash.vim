" Vim syntax file
" Language:	bash
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 13

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
