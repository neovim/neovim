" Vim filetype plugin file
" Language:	gdb
" Maintainer:	Michaël Peeters <NOSPAMm.vim@noekeon.org>
" Last Changed: 2017-10-26
"               2024-04-10:	- add Matchit support (by Vim Project)

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

setlocal commentstring=#%s
setlocal include=^\\s*source

" Undo the stuff we changed.
let b:undo_ftplugin = "setlocal cms< include<"

" Matchit support
if !exists('b:match_words')
  let b:match_words = '\<\%(if\|while\|define\|document\)\>:\<else\>:\<end\>'
  let b:undo_ftplugin ..= " | unlet! b:match_words"
endif
