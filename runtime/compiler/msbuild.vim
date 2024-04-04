" Vim compiler file
" Compiler:	Microsoft Visual Studio C#
" Maintainer:	Chiel ten Brinke (ctje92@gmail.com)
" Last Change:	2013 May 13
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "msbuild"
let s:keepcpo= &cpo
set cpo&vim

CompilerSet errorformat=\ %#%f(%l\\\,%c):\ %m
CompilerSet makeprg=msbuild\ /nologo\ /v:q\ /property:GenerateFullPaths=true

let &cpo = s:keepcpo
unlet s:keepcpo
