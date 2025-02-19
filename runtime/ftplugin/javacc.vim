" Vim filetype plugin
" Language:	JavaCC
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2024 Jul 06

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal formatoptions-=t formatoptions+=croql

" Set 'comments' to format dashed lists in comments. Behaves just like C.
setlocal comments& comments^=sO:*\ -,mO:*\ \ ,exO:*/

setlocal commentstring=//\ %s

let b:undo_ftplugin = 'setl fo< com< cms<'
