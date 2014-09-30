" Vim filetype plugin file
" Language:	matlab
" Maintainer:	Jake Wasserman <jwasserman at gmail dot com>
" Last Changed: 2006 Jan 12

if exists("b:did_ftplugin")
	finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo-=C

if exists("loaded_matchit")
	let s:conditionalEnd = '\(([^()]*\)\@!\<end\>\([^()]*)\)\@!'
	let b:match_words = '\<if\>\|\<while\>\|\<for\>\|\<switch\>:' .
		\ s:conditionalEnd . ',\<if\>:\<elseif\>:\<else\>:' .
		\ s:conditionalEnd
endif

setlocal suffixesadd=.m
setlocal suffixes+=.asv

let b:undo_ftplugin = "setlocal suffixesadd< suffixes< "
	\ . "| unlet! b:match_words"

let &cpo = s:save_cpo
unlet s:save_cpo
