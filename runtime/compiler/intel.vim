" Vim compiler file
" Compiler:     Intel C++ 7.1
" Maintainer:   David Harrison <david_jr@users.sourceforge.net>
" Last Change:  2012 Apr 30

if exists("current_compiler")
  finish
endif
let current_compiler = "intel"
let s:keepcpo= &cpo
set cpo&vim

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet errorformat=%E%f(%l):\ error:\ %m,
		    \%W%f(%l):\ warning:\ %m,
		    \%I%f(%l):\ remark\ #%n:\ %m,
		    \%+C\ \ %m.,
		    \%-Z\ \ %p^,
		    \%-G\\s%#,
		    \%-G%.%#

let &cpo = s:keepcpo
unlet s:keepcpo
