" Vim compiler file
" Compiler: Hare Compiler
" Maintainer: Amelia Clarke <me@rsaihe.dev>
" Last Change: 2022-09-21
"              2024 Apr 05 by The Vim Project (removed :CompilerSet definition)

if exists("g:current_compiler")
  finish
endif
let g:current_compiler = "hare"

let s:cpo_save = &cpo
set cpo&vim

if filereadable("Makefile") || filereadable("makefile")
  CompilerSet makeprg=make
else
  CompilerSet makeprg=hare\ build
endif

CompilerSet errorformat=
  \Error\ %f:%l:%c:\ %m,
  \Syntax\ error:\ %.%#\ at\ %f:%l:%c\\,\ %m,
  \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: tabstop=2 shiftwidth=2 expandtab
