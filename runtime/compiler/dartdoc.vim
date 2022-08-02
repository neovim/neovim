" Vim compiler file
" Compiler:	Dart Documentation Generator
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2019 May 08

if exists("current_compiler")
  finish
endif
let current_compiler = "dartdoc"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=dartdoc
CompilerSet errorformat=\ \ %tarning:\ %m,
		       \\ \ %trror:\ %m,
		       \%+EGeneration\ failed:\ %m,
		       \%+ISuccess!\ Docs\ generated\ into\ %f,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
