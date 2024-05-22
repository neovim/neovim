" Vim filetype plugin
" Language:	rescript
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2024 May 21

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:// commentstring=//\ %s

let b:undo_ftplugin = 'setl com< cms<'
