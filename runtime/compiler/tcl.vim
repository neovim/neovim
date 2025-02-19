" Vim compiler file
" Compiler:	tcl
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "tcl"

CompilerSet makeprg=tcl

CompilerSet errorformat=%EError:\ %m,%+Z\ %\\{4}(file\ \"%f\"\ line\ %l),%-G%.%#
