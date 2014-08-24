" Vim compiler file
" Compiler:	Checkstyle
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2013 Jun 26

if exists("current_compiler")
  finish
endif
let current_compiler = "checkstyle"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=java\ com.puppycrawl.tools.checkstyle.Main\ -f\ plain

" sample error: WebTable.java:282: '+=' is not preceded with whitespace.
"		WebTable.java:201:1: '{' should be on the previous line.
CompilerSet errorformat=%f:%l:%v:\ %m,%f:%l:\ %m,%-G%.%#
