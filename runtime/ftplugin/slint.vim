" Vim filetype plugin
" Language:	slint
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2024 May 19

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

" Set 'comments' to format dashed lists in comments.
" Also include ///, used for Doxygen.
setl comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:///,:// commentstring=//\ %s

let b:undo_ftplugin = 'setl com< cms<'
