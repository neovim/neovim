" Vim filetype plugin
" Language:	Yacc
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2024 Jul 06

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

" Set 'comments' to format dashed lists in comments.
" Also include ///, used for Doxygen.
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:///,://
setlocal commentstring=//\ %s

let b:undo_ftplugin = 'setl com< cms<'
