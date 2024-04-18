" Vim compiler file
" Compiler:	Dart to JavaScript Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "dart2js"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=dart2js
CompilerSet errorformat=%E%f:%l:%c:,
		       \%-GError:\ Compilation\ failed.,
		       \%CError:\ %m,
		       \%Z\ %#^%\\+,
		       \%C%.%#,
		       \%trror:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
