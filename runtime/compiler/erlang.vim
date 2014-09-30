" Vim compiler file
" Compiler:     Erlang
" Maintainer:	Dmitry Vasiliev <dima at hlabs dot org>
" Last Change:	2012-02-13

if exists("current_compiler")
  finish
endif
let current_compiler = "erlang"

CompilerSet makeprg=erlc\ -Wall\ %

CompilerSet errorformat=%f:%l:\ %m
