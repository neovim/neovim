" Vim compiler file
" Compiler:	SGI IRIX 5.3 cc
" Maintainer:	David Harrison <david_jr@users.sourceforge.net>
" Last Change:	2012 Apr 30
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "irix5_c"
let s:keepcpo= &cpo
set cpo&vim

CompilerSet errorformat=\%Ecfe:\ Error:\ %f\\,\ line\ %l:\ %m,
		     \%Wcfe:\ Warning:\ %n:\ %f\\,\ line\ %l:\ %m,
		     \%Wcfe:\ Warning\ %n:\ %f\\,\ line\ %l:\ %m,
		     \%W(%l)\ \ Warning\ %n:\ %m,
		     \%-Z\ %p^,
		     \-G\\s%#,
		     \%-G%.%#

let &cpo = s:keepcpo
unlet s:keepcpo
