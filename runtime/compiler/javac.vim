" Vim compiler file
" Compiler:	Java Development Kit Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Nov 19 (enable local javac_makeprg_params)

if exists("current_compiler")
  finish
endif
let current_compiler = "javac"

let s:cpo_save = &cpo
set cpo&vim

execute $'CompilerSet makeprg=javac\ {escape(get(b:, 'javac_makeprg_params', get(g:, 'javac_makeprg_params', '')), ' \|"')}'

CompilerSet errorformat=%E%f:%l:\ error:\ %m,
		       \%W%f:%l:\ warning:\ %m,
		       \%-Z%p^,
		       \%-C%.%#,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
