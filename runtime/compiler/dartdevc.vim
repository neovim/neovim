" Vim compiler file
" Compiler:	Dart Development Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2026 Aug 04

if exists("current_compiler")
  finish
endif
let current_compiler = "dartdevc"

let s:cpo_save = &cpo
set cpo&vim

" DEPRECATED: discontinued as of Dart 2.18 (remove in release after Vim 9.2)
CompilerSet makeprg=dartdevc
CompilerSet errorformat=%E%f:%l:%c:\ Error:\ %m,
		       \%CTry\ %.%#,
		       \%Z\ %#^%\\+,
		       \%Z%$,
		       \%C%.%#,
		       \%E%f:\ %trror:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
