" Vim compiler file
" Compiler:	se (Liberty Eiffel Compiler)
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "se"

let s:cpo_save = &cpo
set cpo-=C

CompilerSet makeprg=se\ c

CompilerSet errorformat=%W******\ Warning:\ %m,
		    \%E******\ Fatal\ Error:\ %m,
		    \%E******\ Error:\ %m,
		    \%ZLine\ %l\ column\ %c\ in\ %.%#\ (%f)\ %\\=:,
		    \%ZLine\ %l\ columns\ %c\\,\ %\\d%\\+\ %.%#\ (%f)\ %\\=:,
		    \%+C%*[^\ ]%.%#,
		    \%-GThe\ source\ lines\ involved,
		    \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
