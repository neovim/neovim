" Vim compiler file
" Compiler:	Critical Mass Modula-3 Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2021 Apr 08

if exists("current_compiler")
  finish
endif
let current_compiler = "cm3"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

" TODO: better handling of Quake errors
CompilerSet makeprg=cm3
CompilerSet errorformat=%D---\ building\ in\ %f\ ---,
		       \%W\"%f\"\\,\ line\ %l:\ warning:\ %m,
		       \%E\"%f\"\\,\ line\ %l:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
