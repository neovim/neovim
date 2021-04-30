" Vim compiler file
" Compiler:    Standard for JavaScript
" Maintainer:  Romain Lafourcade <romainlafourcade@gmail.com>
" Last Change: 2020 August 20

if exists("current_compiler")
  finish
endif
let current_compiler = "standard"

if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=npx\ standard
CompilerSet errorformat=%f:%l:%c:\ %m,%-G%.%#
