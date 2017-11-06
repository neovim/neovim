" Vim compiler file
" Compiler:             reStructuredText Documentation Format
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("current_compiler")
  finish
endif
let current_compiler = "rst"

let s:cpo_save = &cpo
set cpo&vim

setlocal errorformat=
      \%f:%l:\ (%tEBUG/0)\ %m,
      \%f:%l:\ (%tNFO/1)\ %m,
      \%f:%l:\ (%tARNING/2)\ %m,
      \%f:%l:\ (%tRROR/3)\ %m,
      \%f:%l:\ (%tEVERE/3)\ %m,
      \%D%*\\a[%*\\d]:\ Entering\ directory\ `%f',
      \%X%*\\a[%*\\d]:\ Leaving\ directory\ `%f',
      \%DMaking\ %*\\a\ in\ %f

let &cpo = s:cpo_save
unlet s:cpo_save
