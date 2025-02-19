" Vim compiler file
" Compiler:	Dart VM
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "dart"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=dart
CompilerSet errorformat=%E%f:%l:%c:\ Error:\ %m,
		       \%CTry\ %.%#,
		       \%Z\ %#^%\\+,
		       \%C%.%#,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
