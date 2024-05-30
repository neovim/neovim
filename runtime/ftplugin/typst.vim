" Vim filetype plugin
" Language:	typst
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2024 May 19

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s

let b:undo_ftplugin = 'setl com< cms<'
