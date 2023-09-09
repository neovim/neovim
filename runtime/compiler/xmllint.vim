" Vim compiler file
" Compiler:	Libxml2 Command-Line Tool
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2020 Jul 30

if exists("current_compiler")
  finish
endif
let current_compiler = "xmllint"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=xmllint\ --valid\ --noout
CompilerSet errorformat=%E%f:%l:\ %.%#\ error\ :\ %m,
		       \%W%f:%l:\ %.%#\ warning\ :\ %m,
		       \%-Z%p^,
		       \%C%.%#,
		       \%terror:\ %m,
		       \%tarning:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
