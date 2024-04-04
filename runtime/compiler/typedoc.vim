" Vim compiler file
" Compiler:	TypeDoc
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "typedoc"

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=npx\ typedoc

CompilerSet makeprg=typedoc
CompilerSet errorformat=%EError:\ %f(%l),
		       \%WWarning:\ %f(%l),
		       \%+IDocumentation\ generated\ at\ %f,
		       \%Z\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
