" Vim compiler file
" Compiler:	JSON Lint
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2019 Jul 10

if exists("current_compiler")
  finish
endif
let current_compiler = "jsonlint"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=npx\ jsonlint\ --compact\ --quiet

CompilerSet makeprg=jsonlint\ --compact\ --quiet
CompilerSet errorformat=%f:\ line\ %l\\,\ col\ %c\\,\ found:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
