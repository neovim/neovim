" Vim compiler file
" Compiler:     raco (Racket command-line tools)
" Maintainer:   D. Ben Knoble <ben.knoble+github@gmail.com>
" URL:          https://github.com/benknoble/vim-racket
" Last Change: 2022 Aug 12
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

let current_compiler = 'raco'

CompilerSet makeprg=raco
CompilerSet errorformat=%f:%l:%c:%m
