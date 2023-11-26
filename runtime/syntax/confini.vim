" Vim syntax file
" Language: confini

" Quit if a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Use the cfg syntax for now, it's similar.
runtime! syntax/cfg.vim

let b:current_syntax = 'confini'
