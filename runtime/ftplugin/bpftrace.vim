" Vim filetype plugin
" Language:     bpftrace
" Maintainer:	Stanislaw Gruszka <stf_xl@wp.pl>
" Last Change:	2025 Dec 05

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s

let b:undo_ftplugin = "setlocal comments< commentstring<"
