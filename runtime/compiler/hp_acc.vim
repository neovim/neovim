" Vim compiler file
" Compiler:	HP aCC
" Maintainer:	Matthias Ulrich <matthias-ulrich@web.de>
" URL:          http://www.subhome.de/vim/hp_acc.vim
" Last Change:	2012 Apr 30
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)
"
"  aCC --version says: "HP ANSI C++ B3910B A.03.13"
"  This compiler has been tested on:
"       hp-ux 10.20, hp-ux 11.0 and hp-ux 11.11 (64bit)
"
"  Tim Brown's aCC is: "HP ANSI C++ B3910B A.03.33"
"  and it also works fine...
"  
"  Now suggestions by aCC are supported (compile flag aCC +w).
"  Thanks to Tim Brown again!!
"  

if exists("current_compiler")
  finish
endif
let current_compiler = "hp_acc"
let s:keepcpo= &cpo
set cpo&vim

CompilerSet errorformat=%A%trror\ %n\:\ \"%f\"\\,\ line\ %l\ \#\ %m,
         \%A%tarning\ (suggestion)\ %n\:\ \"%f\"\\,\ line\ %l\ \#\ %m\ %#,
         \%A%tarning\ %n\:\ \"%f\"\\,\ line\ %l\ \#\ %m\ %#,
         \%Z\ \ \ \ %p^%.%#,
         \%-C%.%#

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:ts=8:sw=4:cindent
