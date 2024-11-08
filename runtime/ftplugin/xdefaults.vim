" Vim filetype plugin file
" Language:		X resources files like ~/.Xdefaults (xrdb)
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Latest Revision:	2008 Jul 09
"			2024 Jun 03 by Riley Bruins <ribru17@gmail.com> ('commentstring')

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< inc< fo<"

setlocal comments=s1:/*,mb:*,ex:*/,:! commentstring=!\ %s inc&
setlocal formatoptions-=t formatoptions+=croql

let &cpo = s:cpo_save
unlet s:cpo_save
