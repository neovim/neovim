" Vim compiler file
" Compiler:	Jest
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2021 Nov 20

if exists("current_compiler")
  finish
endif
let current_compiler = "jest"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=npx\ --no-install\ jest\ --no-colors

CompilerSet makeprg=jest\ --no-colors
CompilerSet errorformat=%-A\ \ ●\ Console,
		       \%E\ \ ●\ %m,
		       \%Z\ %\\{4}%.%#Error:\ %f:\ %m\ (%l:%c):%\\=,
		       \%Z\ %\\{6}at\ %\\S%#\ (%f:%l:%c),
		       \%Z\ %\\{6}at\ %\\S%#\ %f:%l:%c,
		       \%+C\ %\\{4}%\\w%.%#,
		       \%+C\ %\\{4}%[-+]%.%#,
		       \%-C%.%#,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
