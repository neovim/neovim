" Vim compiler file
" Compiler:	RuboCop
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2019 Jul 10

if exists("current_compiler")
  finish
endif
let current_compiler = "rubocop"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=rubocop\ --format\ emacs
CompilerSet errorformat=%f:%l:%c:\ %t:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
