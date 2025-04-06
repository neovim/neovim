" Vim filetype plugin
" Language:	Lex and Flex
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2024 Jul 06

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s

let b:undo_ftplugin = 'setl com< cms<'
