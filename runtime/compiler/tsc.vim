" Vim compiler file
" Compiler:	TypeScript Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "tsc"

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=npx\ tsc

CompilerSet makeprg=tsc
CompilerSet errorformat=%f\ %#(%l\\,%c):\ %trror\ TS%n:\ %m,
		       \%trror\ TS%n:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
