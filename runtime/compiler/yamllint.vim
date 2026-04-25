" Vim compiler file
" Compiler:    Yamllint for YAML
" Maintainer:  Romain Lafourcade <romainlafourcade@gmail.com>
" Last Change: 2021 July 21
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)
"              2025 Nov 16 by The Vim Project (set errorformat)

if exists("current_compiler")
    finish
endif
let current_compiler = "yamllint"

CompilerSet makeprg=yamllint\ -f\ parsable
" CompilerSet errorformat=%f:%l:%c:\ [%t%*[^]]]\ %m,%f:%l:%c:\ [%*[^]]]\ %m
CompilerSet errorformat&

