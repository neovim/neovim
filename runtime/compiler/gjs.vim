" Vim compiler file
" Compiler:	GJS (Gnome JavaScript Bindings)
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2019 Jul 10

if exists("current_compiler")
  finish
endif
let current_compiler = "gjs"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=gjs
CompilerSet errorformat=%.%#JS\ %tRROR:\ %m\ @\ %f:%c,
		       \%E%.%#JS\ ERROR:\ %m,
		       \%Z@%f:%l:%c,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
