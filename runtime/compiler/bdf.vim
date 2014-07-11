" Vim compiler file
" Compiler:         BDF to PCF Conversion
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-04-19

if exists("current_compiler")
  finish
endif
let current_compiler = "bdf"

let s:cpo_save = &cpo
set cpo-=C

setlocal makeprg=bdftopcf\ $*

setlocal errorformat=%ABDF\ %trror\ on\ line\ %l:\ %m,
      \%-Z%p^,
      \%Cbdftopcf:\ bdf\ input\\,\ %f\\,\ corrupt,
      \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
