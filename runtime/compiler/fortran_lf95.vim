" Vim compiler file
" Compiler:	Lahey/Fujitsu Fortran 95
" URL:		http://www.unb.ca/chem/ajit/compiler/fortran_lf95.vim
" Maintainer:	Ajit J. Thakkar (ajit AT unb.ca); <http://www.unb.ca/chem/ajit/>
" Version:	0.2
" Last Change:	2004 Mar 27
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "fortran_lf95"

let s:cposet=&cpoptions
set cpoptions-=C

CompilerSet errorformat=\ %#%n-%t:\ \"%f\"\\,\ line\ %l:%m,
      \Error\ LINK\.%n:%m,
      \Warning\ LINK\.%n:%m,
      \%-G%.%#
CompilerSet makeprg=lf95

let &cpoptions=s:cposet
unlet s:cposet
