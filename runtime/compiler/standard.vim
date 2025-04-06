" Vim compiler file
" Compiler:    Standard for JavaScript
" Maintainer:  Romain Lafourcade <romainlafourcade@gmail.com>
" Last Change: 2020 August 20
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "standard"

CompilerSet makeprg=npx\ standard
CompilerSet errorformat=%f:%l:%c:\ %m,%-G%.%#
