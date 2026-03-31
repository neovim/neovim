" Vim compiler file
" Compiler:	RuboCop
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "rubocop"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=rubocop\ --format\ emacs
CompilerSet errorformat=%f:%l:%c:\ %t:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
