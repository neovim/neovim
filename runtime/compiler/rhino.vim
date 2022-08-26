" Vim compiler file
" Compiler:	Rhino Shell (JavaScript in Java)
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2019 Jul 10

if exists("current_compiler")
  finish
endif
let current_compiler = "rhino"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=java\ -jar\ lib/rhino-X.X.XX.jar\ -w\ -strict

CompilerSet makeprg=rhino
CompilerSet errorformat=%-Gjs:\ %.%#Compilation\ produced%.%#,
		       \%Ejs:\ \"%f\"\\,\ line\ %l:\ %m,
		       \%Ejs:\ uncaught\ JavaScript\ runtime\ exception:\ %m,
		       \%Wjs:\ warning:\ \"%f\"\\,\ line\ %l:\ %m,
		       \%Zjs:\ %p^,
		       \%Cjs:\ %.%#,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
