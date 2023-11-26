" Vim compiler file
" Compiler:    ESLint for JavaScript
" Maintainer:  Romain Lafourcade <romainlafourcade@gmail.com>
" Last Change: 2020 August 20

if exists("current_compiler")
  finish
endif
let current_compiler = "eslint"

if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=npx\ eslint\ --format\ compact
CompilerSet errorformat=%f:\ line\ %l\\,\ col\ %c\\,\ %m,%-G%.%#
