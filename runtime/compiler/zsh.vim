" Vim compiler file
" Compiler:	Zsh
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "zsh"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=zsh\ -n\ --\ %:S
CompilerSet errorformat=%f:\ line\ %l:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
