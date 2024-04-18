" Vim compiler file
" Compiler:	Dart Formatter
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "dartfmt"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=dartfmt
CompilerSet errorformat=%Eline\ %l\\,\ column\ %c\ of\ %f:\ %m,
		       \%Z\ %\\{3}│\ %\\+^%\\+,
		       \%C%.%#,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
