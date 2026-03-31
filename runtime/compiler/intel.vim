" Vim compiler file
" Compiler:     Intel C++ 7.1
" Maintainer:   David Harrison <david_jr@users.sourceforge.net>
" Last Change:  2012 Apr 30
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "intel"
let s:keepcpo= &cpo
set cpo&vim

CompilerSet errorformat=%E%f(%l):\ error:\ %m,
		    \%W%f(%l):\ warning:\ %m,
		    \%I%f(%l):\ remark\ #%n:\ %m,
		    \%+C\ \ %m.,
		    \%-Z\ \ %p^,
		    \%-G\\s%#,
		    \%-G%.%#

let &cpo = s:keepcpo
unlet s:keepcpo
