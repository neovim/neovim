" Vim compiler file
" Compiler:	Haml
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2016 Aug 29
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "haml"

let s:cpo_save = &cpo
set cpo-=C

CompilerSet makeprg=haml

CompilerSet errorformat=
      \Haml\ %trror\ on\ line\ %l:\ %m,
      \Syntax\ %trror\ on\ line\ %l:\ %m,
      \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:set sw=2 sts=2:
