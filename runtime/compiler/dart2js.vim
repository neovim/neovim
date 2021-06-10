" Vim compiler file
" Compiler:	Dart to JavaScript Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2019 May 08

if exists("current_compiler")
  finish
endif
let current_compiler = "dart2js"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

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
