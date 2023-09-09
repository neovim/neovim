" Vim compiler file
" Compiler:	SGI IRIX 5.3 cc
" Maintainer:	David Harrison <david_jr@users.sourceforge.net>
" Last Change:	2012 Apr 30

if exists("current_compiler")
  finish
endif
let current_compiler = "irix5_c"
let s:keepcpo= &cpo
set cpo&vim

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet errorformat=\%Ecfe:\ Error:\ %f\\,\ line\ %l:\ %m,
		     \%Wcfe:\ Warning:\ %n:\ %f\\,\ line\ %l:\ %m,
		     \%Wcfe:\ Warning\ %n:\ %f\\,\ line\ %l:\ %m,
		     \%W(%l)\ \ Warning\ %n:\ %m,
		     \%-Z\ %p^,
		     \-G\\s%#,
		     \%-G%.%#

let &cpo = s:keepcpo
unlet s:keepcpo
