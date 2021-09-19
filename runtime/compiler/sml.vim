" Vim compiler file
" Compiler:	SML/NJ Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2020 Feb 10

if exists("current_compiler")
  finish
endif
let current_compiler = "sml"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=sml
CompilerSet errorformat=%f:%l.%c-%\\d%\\+.%\\d%\\+\ %trror:\ %m,
		       \%f:%l.%c\ %trror:\ %m,
		       \%trror:\ %m
		       \%f:%l.%c-%\\d%\\+.%\\d%\\+\ %tarning:\ %m,
		       \%f:%l.%c\ %tarning:\ %m,
		       \%tarning:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
