" Vim compiler file
" Compiler:    Spectral for YAML
" Maintainer:  Romain Lafourcade <romainlafourcade@gmail.com>
" Last Change: 2021 July 21

if exists("current_compiler")
    finish
endif
let current_compiler = "spectral"

if exists(":CompilerSet") != 2
    command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=spectral\ lint\ %\ -f\ text
CompilerSet errorformat=%f:%l:%c\ %t%.%\\{-}\ %m

