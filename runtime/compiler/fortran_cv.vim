" Vim compiler file
" Compiler:	Compaq Visual Fortran
" Maintainer:	Joh.-G. Simon (johann-guenter.simon@linde-le.com)
" Last Change:	11/05/2002

if exists("current_compiler")
  finish
endif
let current_compiler = "fortran_cv"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cposet = &cpoptions
set cpoptions-=C

" A workable errorformat for Compaq Visual Fortran
CompilerSet errorformat=
		\%E%f(%l)\ :\ Error:%m,
		\%W%f(%l)\ :\ Warning:%m,
		\%-Z%p%^%.%#,
		\%-G%.%#,
" Compiler call
CompilerSet makeprg=df\ /nologo\ /noobj\ /c\ %
" Visual fortran defaults to printing output on stderr
" Adjust option shellpipe accordingly

let &cpoptions = s:cposet
unlet s:cposet
