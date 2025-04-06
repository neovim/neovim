" Vim compiler file
" Compiler:	TypeScript Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03
"		2025 Mar 11 by The Vim Project (add comment for Dispatch, add tsc_makeprg variable)

if exists("current_compiler")
  finish
endif
let current_compiler = "tsc"

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=tsc
" CompilerSet makeprg=npx\ tsc
execute $'CompilerSet makeprg={escape(get(b:, 'tsc_makeprg', get(g:, 'tsc_makeprg', 'tsc')), ' \|"')}'
CompilerSet errorformat=%f\ %#(%l\\,%c):\ %trror\ TS%n:\ %m,
		       \%trror\ TS%n:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
