" Vim compiler file
" Compiler:	Unit testing tool for Python
" Maintainer:	Max Ischenko <mfi@ukr.net>
" Last Change: 2004 Mar 27
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "pyunit"

CompilerSet efm=%C\ %.%#,%A\ \ File\ \"%f\"\\,\ line\ %l%.%#,%Z%[%^\ ]%\\@=%m

