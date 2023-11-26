" Vim compiler file
" Compiler:	Zsh
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2020 Sep 6

if exists("current_compiler")
  finish
endif
let current_compiler = "zsh"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=zsh\ -n\ --\ %:S
CompilerSet errorformat=%f:\ line\ %l:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
