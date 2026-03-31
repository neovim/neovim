" Vim compiler file
" Compiler:	XO
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "xo"

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=npx\ xo\ --reporter\ compact

CompilerSet makeprg=xo\ --reporter\ compact
CompilerSet errorformat=%f:\ line\ %l\\,\ col\ %c\\,\ %trror\ %m,
		       \%f:\ line\ %l\\,\ col\ %c\\,\ %tarning\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
