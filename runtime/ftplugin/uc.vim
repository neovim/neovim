" Vim filetype plugin
" Language:	UnrealScript
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2025 Jul 19

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://
setl commentstring=//\ %s

let b:undo_ftplugin = 'setl com< cms<'
