" Vim compiler file.
" Compiler:    Hare
" Maintainer:  Amelia Clarke <selene@perilune.dev>
" Last Change: 2024-05-23
" Upstream:    https://git.sr.ht/~sircmpwn/hare.vim

if exists('current_compiler')
  finish
endif
let current_compiler = 'hare'

let s:cpo_save = &cpo
set cpo&vim

if filereadable('Makefile') || filereadable('makefile')
  CompilerSet makeprg=make
else
  CompilerSet makeprg=hare\ build
endif

CompilerSet errorformat=
  \%f:%l:%c:\ syntax\ error:\ %m,
  \%f:%l:%c:\ error:\ %m,
  \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: et sts=2 sw=2 ts=8
