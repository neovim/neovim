" Vim compiler file
" Compiler:     FPC 2.1
" Maintainer:   Jaroslaw Blasiok <jaro3000@o2.pl>
" Last Change:  2005 October 07
"               2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "fpc"

" NOTE: compiler must be run with -vb to write whole source path, not only file
" name.
CompilerSet errorformat=%f(%l\\,%c)\ %m
