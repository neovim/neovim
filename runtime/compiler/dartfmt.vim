" Vim compiler file
" Compiler:	Dart Formatter
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2019 May 08

if exists("current_compiler")
  finish
endif
let current_compiler = "dartfmt"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=dartfmt
CompilerSet errorformat=%Eline\ %l\\,\ column\ %c\ of\ %f:\ %m,
		       \%Z\ %\\{3}│\ %\\+^%\\+,
		       \%C%.%#,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
