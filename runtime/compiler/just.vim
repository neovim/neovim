" Vim compiler file
" Compiler:	Just
" Maintainer:	Alarcritty
" Last Change:	2026 Mar 20

if exists("current_compiler")
  finish
endif
let current_compiler = "just"

let s:cpo_save = &cpo
set cpo-=C

CompilerSet makeprg=just

CompilerSet errorformat=
      \%Eerror:\ %m,
      \%C%\\s%#——▶\ %f:%l:%c,
      \%-C%.%#,
      \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
