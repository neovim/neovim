" Vim Compiler File
" Compiler:	Modelsim Vcom
" Maintainer:	Paul Baleme <pbaleme@mail.com>
" Contributors: Enno Nagel
" Last Change:	2024 Mar 29
" Thanks to:    allanherriman@hotmail.com

if exists("current_compiler")
  finish
endif
let current_compiler = "modelsim_vcom"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=vcom

"setlocal errorformat=\*\*\ %tRROR:\ %f(%l):\ %m,%tRROR:\ %f(%l):\ %m,%tARNING\[%*[0-9]\]:\ %f(%l):\ %m,\*\*\ %tRROR:\ %m,%tRROR:\ %m,%tARNING\[%*[0-9]\]:\ %m
"setlocal errorformat=%tRROR:\ %f(%l):\ %m,%tARNING\[%*[0-9]\]:\ %m
CompilerSet errorformat=\*\*\ %tRROR:\ %f(%l):\ %m,\*\*\ %tRROR:\ %m,\*\*\ %tARNING:\ %m,\*\*\ %tOTE:\ %m,%tRROR:\ %f(%l):\ %m,%tARNING\[%*[0-9]\]:\ %f(%l):\ %m,%tRROR:\ %m,%tARNING\[%*[0-9]\]:\ %m

