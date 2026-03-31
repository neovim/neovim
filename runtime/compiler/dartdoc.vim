" Vim compiler file
" Compiler:	Dart Documentation Generator
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "dartdoc"

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
