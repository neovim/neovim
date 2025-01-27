" Vim compiler file
" Compiler:    ESLint for JavaScript
" Maintainer:  Romain Lafourcade <romainlafourcade@gmail.com>
" Last Change: 2024 Nov 30

if exists("current_compiler")
  finish
endif
let current_compiler = "eslint"

CompilerSet makeprg=npx\ eslint\ --format\ stylish
CompilerSet errorformat=%-P%f,\%\\s%#%l:%c\ %#\ %trror\ \ %m,\%\\s%#%l:%c\ %#\ %tarning\ \ %m,\%-Q,\%-G%.%#,
