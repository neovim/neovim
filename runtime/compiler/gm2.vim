" Vim compiler file
" Compiler:	GNU Modula-2 Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "gm2"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=gm2
CompilerSet errorformat=%-G%f:%l:%c:\ error:\ compilation\ failed,
		       \%f:%l:%c:\ %trror:\ %m,
		       \%f:%l:%c:\ %tarning:\ %m,
		       \%f:%l:%c:\ %tote:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
