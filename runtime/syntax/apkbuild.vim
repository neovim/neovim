" Vim syntax file
" Language:	apkbuild
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2024 Dec 22

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" The actual syntax is in sh.vim and controlled by buffer-local variables.
unlet! b:is_bash b:is_kornshell
let b:is_sh = 1

runtime! syntax/sh.vim

let b:current_syntax = 'apkbuild'
