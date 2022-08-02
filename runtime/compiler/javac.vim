" Vim compiler file
" Compiler:	Java Development Kit Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2019 Oct 21

if exists("current_compiler")
  finish
endif
let current_compiler = "javac"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=javac
CompilerSet errorformat=%E%f:%l:\ error:\ %m,
		       \%W%f:%l:\ warning:\ %m,
		       \%-Z%p^,
		       \%-C%.%#,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
