" Vim compiler file
" Compiler:             BDF to PCF Conversion
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Contributors:         Enno Nagel
" Last Change:          2024 Mar 29

if exists("current_compiler")
  finish
endif
let current_compiler = "bdf"

let s:cpo_save = &cpo
set cpo-=C

if exists(":CompilerSet") != 2 " Older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=bdftopcf\ $*
CompilerSet errorformat=%ABDF\ %trror\ on\ line\ %l:\ %m,
      \%-Z%p^,
      \%Cbdftopcf:\ bdf\ input\\,\ %f\\,\ corrupt,
      \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
