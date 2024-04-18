" Vim compiler file
" Compiler:	Stylelint
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "stylelint"

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=npx\ stylelint\ --formatter\ compact

CompilerSet makeprg=stylelint\ --formatter\ compact
CompilerSet errorformat=%f:\ line\ %l\\,\ col\ %c\\,\ %trror\ -\ %m,
		       \%f:\ line\ %l\\,\ col\ %c\\,\ %tarning\ -\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
