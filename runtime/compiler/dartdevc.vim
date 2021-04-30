" Vim compiler file
" Compiler:	Dart Development Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2019 May 08

if exists("current_compiler")
  finish
endif
let current_compiler = "dartdevc"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=dartdevc
CompilerSet errorformat=%E%f:%l:%c:\ Error:\ %m,
		       \%CTry\ %.%#,
		       \%Z\ %#^%\\+,
		       \%Z%$,
		       \%C%.%#,
		       \%E%f:\ %trror:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
