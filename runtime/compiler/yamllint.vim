" Vim compiler file
" Compiler:    Yamllint for YAML
" Maintainer:  Romain Lafourcade <romainlafourcade@gmail.com>
" Last Change: 2021 July 21
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
    finish
endif
let current_compiler = "yamllint"

CompilerSet makeprg=yamllint\ -f\ parsable

