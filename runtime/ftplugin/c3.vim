" Vim filetype plugin
" Language:	C3
" Maintainer:	Turiiya <34311583+ttytm@users.noreply.github.com>
" Last Change:	2024 Nov 24

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:///,://
setl commentstring=//\ %s

let b:undo_ftplugin = 'setl com< cms<'
