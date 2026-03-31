" Vim compiler file
" Compiler:	Cucumber
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2016 Aug 29
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "cucumber"

let s:cpo_save = &cpo
set cpo-=C

CompilerSet makeprg=cucumber

CompilerSet errorformat=
      \%W%m\ (Cucumber::Undefined),
      \%E%m\ (%\\S%#),
      \%Z%f:%l,
      \%Z%f:%l:%.%#

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:set sw=2 sts=2:
