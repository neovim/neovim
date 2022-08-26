" Vim compiler file
" Compiler:		bcc - Borland C
" Maintainer:	Emile van Raaij (eraaij@xs4all.nl)
" Last Change:	2004 Mar 27

if exists("current_compiler")
  finish
endif
let current_compiler = "bcc"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

" A workable errorformat for Borland C
CompilerSet errorformat=%*[^0-9]%n\ %f\ %l:\ %m

" default make
CompilerSet makeprg=make
