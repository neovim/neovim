" Vim Compiler File
" Compiler:	Modelsim Vcom
" Maintainer:	Paul Baleme <pbaleme@mail.com>
" Contributors: Enno Nagel
" Last Change:	2024 Mar 29
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)
" Thanks to:    allanherriman@hotmail.com

if exists("current_compiler")
  finish
endif
let current_compiler = "modelsim_vcom"

CompilerSet makeprg=vcom

"setlocal errorformat=\*\*\ %tRROR:\ %f(%l):\ %m,%tRROR:\ %f(%l):\ %m,%tARNING\[%*[0-9]\]:\ %f(%l):\ %m,\*\*\ %tRROR:\ %m,%tRROR:\ %m,%tARNING\[%*[0-9]\]:\ %m
"setlocal errorformat=%tRROR:\ %f(%l):\ %m,%tARNING\[%*[0-9]\]:\ %m
CompilerSet errorformat=\*\*\ %tRROR:\ %f(%l):\ %m,\*\*\ %tRROR:\ %m,\*\*\ %tARNING:\ %m,\*\*\ %tOTE:\ %m,%tRROR:\ %f(%l):\ %m,%tARNING\[%*[0-9]\]:\ %f(%l):\ %m,%tRROR:\ %m,%tARNING\[%*[0-9]\]:\ %m

