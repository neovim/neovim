" Vim compiler file
" Compiler:	Java Development Kit Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Jun 14

if exists("current_compiler")
  finish
endif
let current_compiler = "javac"

let s:cpo_save = &cpo
set cpo&vim

if exists("g:javac_makeprg_params")
  execute $'CompilerSet makeprg=javac\ {escape(g:javac_makeprg_params, ' \|"')}'
else
  CompilerSet makeprg=javac
endif

CompilerSet errorformat=%E%f:%l:\ error:\ %m,
		       \%W%f:%l:\ warning:\ %m,
		       \%-Z%p^,
		       \%-C%.%#,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
