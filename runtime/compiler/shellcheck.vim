" Vim compiler file
" Compiler:	ShellCheck
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "shellcheck"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=shellcheck\ -f\ gcc
CompilerSet errorformat=%f:%l:%c:\ %trror:\ %m\ [SC%n],
		       \%f:%l:%c:\ %tarning:\ %m\ [SC%n],
		       \%f:%l:%c:\ %tote:\ %m\ [SC%n],
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
