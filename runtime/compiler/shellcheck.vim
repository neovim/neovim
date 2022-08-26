" Vim compiler file
" Compiler:	ShellCheck
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2020 Sep 4

if exists("current_compiler")
  finish
endif
let current_compiler = "shellcheck"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=shellcheck\ -f\ gcc
CompilerSet errorformat=%f:%l:%c:\ %trror:\ %m\ [SC%n],
		       \%f:%l:%c:\ %tarning:\ %m\ [SC%n],
		       \%f:%l:%c:\ %tote:\ %m\ [SC%n],
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
