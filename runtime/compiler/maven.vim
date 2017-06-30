" Vim compiler file
" Compiler:	maven
" Maintainer:	Tim Stewart <tim.j.stewart@gmail.com>
" Last Change:	2017 June 30

if exists("current_compiler")
  finish
endif
let current_compiler = "maven"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=mvn

CompilerSet errorformat=[ERROR]\ %f:[%l\\,%c]\ %m
