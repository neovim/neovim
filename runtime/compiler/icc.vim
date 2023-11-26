" Vim compiler file
" Compiler:		icc - Intel C++
" Maintainer: Peter Puck <PtrPck@netscape.net>
" Last Change: 2004 Mar 27

if exists("current_compiler")
  finish
endif
let current_compiler = "icc"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

" I think that Intel is calling the compiler icl under Windows

CompilerSet errorformat=%-Z%p^,%f(%l):\ remark\ #%n:%m,%f(%l)\ :\ (col.\ %c)\ remark:\ %m,%E%f(%l):\ error:\ %m,%E%f(%l):\ error:\ #%n:\ %m,%W%f(%l):\ warning\ #%n:\ %m,%W%f(%l):\ warning:\ %m,%-C%.%#

