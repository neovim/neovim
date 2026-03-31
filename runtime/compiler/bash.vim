" Vim compiler file
" Compiler:     Bash Syntax Checker
" Maintainer:   @konfekt
" Last Change:  2024 Dec 27

if exists("current_compiler")
   finish
endif
let current_compiler = "bash"

CompilerSet makeprg=bash\ -n
CompilerSet errorformat=%f:\ line\ %l:\ %m
