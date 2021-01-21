" Vim syntax file
" Language:		Idris

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the Haskell syntax to start with:
" Idris and Haskell are very similar
runtime! syntax/haskell.vim
unlet b:current_syntax

let b:current_syntax = "idris"

" Options for vi: ts=8 sw=2 sts=2 nowrap noexpandtab ft=vim
