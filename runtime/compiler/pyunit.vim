" Vim compiler file
" Compiler:	Unit testing tool for Python
" Maintainer:	Max Ischenko <mfi@ukr.net>
" Last Change: 2004 Mar 27

if exists("current_compiler")
  finish
endif
let current_compiler = "pyunit"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet efm=%C\ %.%#,%A\ \ File\ \"%f\"\\,\ line\ %l%.%#,%Z%[%^\ ]%\\@=%m

