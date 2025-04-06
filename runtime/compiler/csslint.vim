" Vim compiler file
" Compiler:	csslint for CSS
" Maintainer:	Daniel Moch <daniel@danielmoch.com>
" Last Change:	2016 May 21
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "csslint"

CompilerSet makeprg=csslint\ --format=compact
CompilerSet errorformat=%-G,%-G%f:\ lint\ free!,%f:\ line\ %l\\,\ col\ %c\\,\ %trror\ -\ %m,%f:\ line\ %l\\,\ col\ %c\\,\ %tarning\ -\ %m,%f:\ line\ %l\\,\ col\ %c\\,\ %m
