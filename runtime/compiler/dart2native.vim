" Vim compiler file
" Compiler:	Dart to Native Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "dart2native"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=dart2native
CompilerSet errorformat=%E%f:%l:%c:\ Error:\ %m,
		       \%CTry\ %.%#,
		       \%Z\ %#^%\\+,
		       \%Z%$,
		       \%C%.%#,
		       \%E%f:\ %trror:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
