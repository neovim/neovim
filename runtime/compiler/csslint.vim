" Vim compiler file
" Compiler:	csslint for CSS
" Maintainer: Daniel Moch <daniel@danielmoch.com>
" Last Change: 2016 May 21

if exists("current_compiler")
  finish
endif
let current_compiler = "csslint"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=csslint\ --format=compact
CompilerSet errorformat=%-G,%-G%f:\ lint\ free!,%f:\ line\ %l\\,\ col\ %c\\,\ %trror\ -\ %m,%f:\ line\ %l\\,\ col\ %c\\,\ %tarning\ -\ %m,%f:\ line\ %l\\,\ col\ %c\\,\ %m
