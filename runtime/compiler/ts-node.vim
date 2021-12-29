" Vim compiler file
" Compiler:	TypeScript Runner
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2020 Feb 10

if exists("current_compiler")
  finish
endif
let current_compiler = "node"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=npx\ ts-node

CompilerSet makeprg=ts-node
CompilerSet errorformat=%f\ %#(%l\\,%c):\ %trror\ TS%n:\ %m,
		       \%E%f:%l,
		       \%+Z%\\w%\\+Error:\ %.%#,
		       \%C%p^%\\+,
		       \%C%.%#,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
