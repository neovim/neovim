" Vim filetype plugin
" Language: Power Query M
" Maintainer: Anarion Dunedain <anarion80@gmail.com>
" Last Change: 2025 Apr 3

if exists('b:did_ftplugin')
  finish
endif

let b:did_ftplugin = 1

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://

setlocal commentstring=//\ %s

let b:undo_ftplugin = 'setl com< cms<'
