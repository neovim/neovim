" Vim compiler file
" Compiler:	Dart to Native Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2026 Aug 04

if exists("current_compiler")
  finish
endif
let current_compiler = "dart2native"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=dart\ compile\ exe
CompilerSet errorformat=%E%f:%l:%c:\ Error:\ %m,
		       \%CTry\ %.%#,
		       \%Z\ %#^%\\+,
		       \%Z%$,
		       \%C%.%#,
		       \%E%f:\ %trror:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
