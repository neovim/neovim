" Vim compiler file
" Compiler:	FreeBASIC Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2015 Jan 10

if exists("current_compiler")
  finish
endif
let current_compiler = "fbc"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=fbc
CompilerSet errorformat=%-G%.%#Too\ many\ errors\\,\ exiting,
		       \%f(%l)\ %tarning\ %n(%\\d%\\+):\ %m,
                       \%E%f(%l)\ error\ %n:\ %m,
		       \%-Z%p^,
		       \%-C%.%#,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
