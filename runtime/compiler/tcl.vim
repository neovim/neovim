" Vim compiler file
" Compiler:	tcl
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2004 Nov 27

if exists("current_compiler")
  finish
endif
let current_compiler = "tcl"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=tcl

CompilerSet errorformat=%EError:\ %m,%+Z\ %\\{4}(file\ \"%f\"\ line\ %l),%-G%.%#
