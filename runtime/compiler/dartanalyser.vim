" Vim compiler file
" Compiler:	Dart Analyzer
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2019 May 08

if exists("current_compiler")
  finish
endif
let current_compiler = "dartanalyzer"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=dartanalyzer\ --format\ machine
CompilerSet errorformat=%t%\\w%\\+\|%\\w%\\+\|%\\w%\\+\|%f\|%l\|%c\|%\\d%\\+\|%m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
