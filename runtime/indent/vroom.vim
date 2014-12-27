" Vim indent file
" Language:	Vroom (vim testing and executable documentation)
" Maintainer:	David Barnett (https://github.com/google/vim-ft-vroom)
" Last Change:	2014 Jul 23

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

let s:cpo_save = &cpo
set cpo-=C


let b:undo_indent = 'setlocal autoindent<'

setlocal autoindent


let &cpo = s:cpo_save
unlet s:cpo_save
