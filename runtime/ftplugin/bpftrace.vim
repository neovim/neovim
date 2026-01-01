" Vim filetype plugin
" Language:     bpftrace
" Maintainer:	Stanislaw Gruszka <stf_xl@wp.pl> (invalid)
" Last Change:	2025 Dec 23

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s

setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setlocal comments< commentstring< formatoptions<"
