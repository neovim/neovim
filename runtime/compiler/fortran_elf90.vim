" Vim compiler file
" Compiler:	Essential Lahey Fortran 90
"		Probably also works for Lahey Fortran 90
" URL:		http://www.unb.ca/chem/ajit/compiler/fortran_elf90.vim
" Maintainer:	Ajit J. Thakkar (ajit AT unb.ca); <http://www.unb.ca/chem/ajit/>
" Version:	0.2
" Last Change:	2004 Mar 27
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "fortran_elf90"

let s:cposet=&cpoptions
set cpoptions-=C

CompilerSet errorformat=\%ALine\ %l\\,\ file\ %f,
      \%C%tARNING\ --%m,
      \%C%tATAL\ --%m,
      \%C%tBORT\ --%m,
      \%+C%\\l%.%#\.,
      \%C%p\|,
      \%C%.%#,
      \%Z%$,
      \%-G%.%#
CompilerSet makeprg=elf90

let &cpoptions=s:cposet
unlet s:cposet
