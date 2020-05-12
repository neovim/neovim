" Vim compiler file
" Compiler:	Pylint for Python
" Maintainer: Daniel Moch <daniel@danielmoch.com>
" Last Change: 2016 May 20

if exists("current_compiler")
  finish
endif
let current_compiler = "pylint"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=pylint\ --output-format=text\ --msg-template=\"{path}:{line}:{column}:{C}:\ [{symbol}]\ {msg}\"\ --reports=no
CompilerSet errorformat=%A%f:%l:%c:%t:\ %m,%A%f:%l:\ %m,%A%f:(%l):\ %m,%-Z%p^%.%#,%-G%.%#
