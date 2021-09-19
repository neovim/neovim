" Vim compiler file
" Compiler:	Nashorn Shell
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2018 Jan 9

if exists("current_compiler")
  finish
endif
let current_compiler = "jjs"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=jjs
CompilerSet errorformat=%f:%l:%c\ %m,
		       \%f:%l\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
