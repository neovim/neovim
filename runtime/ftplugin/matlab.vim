" Vim filetype plugin file
" Language:	matlab
" Maintainer:	Jake Wasserman <jwasserman at gmail dot com>
" Last Change: 	2019 Sep 27

" Contributors:
" Charles Campbell

if exists("b:did_ftplugin")
	finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo-=C

if exists("loaded_matchit")
 let s:conditionalEnd = '\%(([^()]*\)\@!\<end\>\%([^()]*)\)\@!'
 let b:match_words=
   \ '\<\%(if\|switch\|for\|while\)\>:\<\%(elseif\|case\|break\|continue\|else\|otherwise\)\>:'.s:conditionalEnd.','.
   \ '\<function\>:\<return\>:\<endfunction\>'
 unlet s:conditionalEnd
endif

setlocal suffixesadd=.m
setlocal suffixes+=.asv
setlocal commentstring=%\ %s

let b:undo_ftplugin = "setlocal suffixesadd< suffixes< commentstring< "
	\ . "| unlet! b:match_words"

let &cpo = s:save_cpo
unlet s:save_cpo
