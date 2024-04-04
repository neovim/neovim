" Vim compiler file
" Compiler:	Nashorn Shell
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "jjs"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=jjs
CompilerSet errorformat=%f:%l:%c\ %m,
		       \%f:%l\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
