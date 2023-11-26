" Vim filetype plugin file
" Language:	gdb
" Maintainer:	Michaël Peeters <NOSPAMm.vim@noekeon.org>
" Last Changed: 26 Oct 2017

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

setlocal commentstring=#%s

" Undo the stuff we changed.
let b:undo_ftplugin = "setlocal cms<"
