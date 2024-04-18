" Vim compiler file
" Compiler:	Fortran Company/NAGWare F compiler
" URL:		http://www.unb.ca/chem/ajit/compiler/fortran_F.vim
" Maintainer:	Ajit J. Thakkar (ajit AT unb.ca); <http://www.unb.ca/chem/ajit/>
" Version:	0.2
" Last Change:	2004 Mar 27
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "fortran_F"

let s:cposet=&cpoptions
set cpoptions-=C

CompilerSet errorformat=%trror:\ %f\\,\ line\ %l:%m,
      \%tarning:\ %f\\,\ line\ %l:%m,
      \%tatal\ Error:\ %f\\,\ line\ %l:%m,
      \%-G%.%#
CompilerSet makeprg=F

let &cpoptions=s:cposet
unlet s:cposet
