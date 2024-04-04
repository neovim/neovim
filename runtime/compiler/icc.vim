" Vim compiler file
" Compiler:		icc - Intel C++
" Maintainer: Peter Puck <PtrPck@netscape.net>
" Last Change: 2004 Mar 27
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "icc"

" I think that Intel is calling the compiler icl under Windows

CompilerSet errorformat=%-Z%p^,%f(%l):\ remark\ #%n:%m,%f(%l)\ :\ (col.\ %c)\ remark:\ %m,%E%f(%l):\ error:\ %m,%E%f(%l):\ error:\ #%n:\ %m,%W%f(%l):\ warning\ #%n:\ %m,%W%f(%l):\ warning:\ %m,%-C%.%#

