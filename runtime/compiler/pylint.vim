" Vim compiler file
" Compiler:	Pylint for Python
" Maintainer: Daniel Moch <daniel@danielmoch.com>
" Last Change: 2016 May 20
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "pylint"

CompilerSet makeprg=pylint\ --output-format=text\ --msg-template=\"{path}:{line}:{column}:{C}:\ [{symbol}]\ {msg}\"\ --reports=no
CompilerSet errorformat=%A%f:%l:%c:%t:\ %m,%A%f:%l:\ %m,%A%f:(%l):\ %m,%-Z%p^%.%#,%-G%.%#
