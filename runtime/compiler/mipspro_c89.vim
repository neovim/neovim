" Vim compiler file
" Compiler:	SGI IRIX 6.5 MIPSPro C (c89)
" Maintainer:	David Harrison <david_jr@users.sourceforge.net>
" Last Change:	2012 Apr 30
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "mipspro_c89"
let s:keepcpo= &cpo
set cpo&vim

CompilerSet errorformat=%Ecc\-%n\ %.%#:\ ERROR\ File\ =\ %f\%\\,\ Line\ =\ %l,
		    \%Wcc\-%n\ %.%#:\ WARNING\ File\ =\ %f\%\\,\ Line\ =\ %l,
		    \%Icc\-%n\ %.%#:\ REMARK\ File\ =\ %f\%\\,\ Line\ =\ %l,
		    \%-Z%p%^,
		    \%+C\ %\\{10}%m%.,
		    \%+C\ \ %m,
		    \%-G\\s%#,
		    \%-G%.%#

let &cpo = s:keepcpo
unlet s:keepcpo
