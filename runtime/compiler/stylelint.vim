" Vim compiler file
" Compiler:	Stylelint
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2020 Jun 10

if exists("current_compiler")
  finish
endif
let current_compiler = "stylelint"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=npx\ stylelint\ --formatter\ compact

CompilerSet makeprg=stylelint\ --formatter\ compact
CompilerSet errorformat=%f:\ line\ %l\\,\ col\ %c\\,\ %trror\ -\ %m,
		       \%f:\ line\ %l\\,\ col\ %c\\,\ %tarning\ -\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
