" Vim compiler file
" Compiler:	javac
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2004 Nov 27

if exists("current_compiler")
  finish
endif
let current_compiler = "javac"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=javac

CompilerSet errorformat=%E%f:%l:\ %m,%-Z%p^,%-C%.%#,%-G%.%#
