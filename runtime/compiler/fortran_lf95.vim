" Vim compiler file
" Compiler:	Lahey/Fujitsu Fortran 95
" URL:		http://www.unb.ca/chem/ajit/compiler/fortran_lf95.vim
" Maintainer:	Ajit J. Thakkar (ajit AT unb.ca); <http://www.unb.ca/chem/ajit/>
" Version:	0.2
" Last Change: 2004 Mar 27

if exists("current_compiler")
  finish
endif
let current_compiler = "fortran_lf95"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cposet=&cpoptions
set cpoptions-=C

CompilerSet errorformat=\ %#%n-%t:\ \"%f\"\\,\ line\ %l:%m,
      \Error\ LINK\.%n:%m,
      \Warning\ LINK\.%n:%m,
      \%-G%.%#
CompilerSet makeprg=lf95

let &cpoptions=s:cposet
unlet s:cposet
