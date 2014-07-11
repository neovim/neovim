" Vim compiler file
" Compiler:     g77 (GNU Fortran)
" Maintainer:   Ralf Wildenhues <Ralf.Wildenhues@gmx.de>
" Last Change:  $Date: 2004/06/13 18:17:36 $
" $Revision: 1.1 $

if exists("current_compiler")
  finish
endif
let current_compiler = "fortran_g77"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo-=C

" Note: The errorformat assumes GNU make

" sample multiline errors (besides gcc backend one-liners):
" gev.f:14:
"	   parameter UPLO = 'Upper-triangle'
"	   ^
" Unsupported VXT statement at (^)
" gev.f:6:
"	   integer	   desca( * ), descb( * )
"			   1
" gev.f:19: (continued):
"	   end subroutine
"	   2
" Invalid declaration of or reference to symbol `desca' at (2) [initially seen at (1)]

CompilerSet errorformat=
	\%Omake:\ %r,
	\%f:%l:\ warning:\ %m,
	\%A%f:%l:\ (continued):,
	\%W%f:%l:\ warning:,
	\%A%f:%l:\ ,
	\%-C\ \ \ %p%*[0123456789^]%.%#,
	\%-C\ \ \ %.%#,
	\%D%*\\a[%*\\d]:\ Entering\ directory\ `%f',
	\%X%*\\a[%*\\d]:\ Leaving\ directory\ `%f',
	\%DMaking\ %*\\a\ in\ %f,
	\%Z%m

let &cpo = s:cpo_save
unlet s:cpo_save
