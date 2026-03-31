" Vim compiler file
" Compiler:     Erlang
" Maintainer:	Dmitry Vasiliev <dima at hlabs dot org>
" Last Change:	2019 Jul 23
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "erlang"

CompilerSet makeprg=erlc\ -Wall\ %:S

CompilerSet errorformat=%f:%l:\ %m
