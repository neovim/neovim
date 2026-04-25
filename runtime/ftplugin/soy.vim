" Vim filetype plugin
" Language:	Soy (Closure Templates)
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2025 Oct 24

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s

let b:undo_ftplugin = "setlocal comments< commentstring<"
