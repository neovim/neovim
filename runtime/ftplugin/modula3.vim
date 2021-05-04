" Vim filetype plugin file
" Language:	Modula-3
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2021 Apr 08

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=s0:(*,mb:\ ,ex:*)
setlocal commentstring=(*%s*)
setlocal formatoptions-=t formatoptions+=croql

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_words = '\<REPEAT\>:\<UNTIL\>,' ..
		    \ '\<\%(BEGIN\|CASE\|FOR\|IF\|LOCK\|LOOP\|TRY\|TYPECASE\|WHILE\|WITH\)\>' ..
		    \	':' ..
		    \	'\<\%(ELSIF\|ELSE\|EXCEPT\|FINALLY\)\>\|\%(^\s*\)\@<=\S.*=>' ..
		    \	':' ..
		    \ '\<END\>'
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Modula-3 Source Files (*.m3)\t*.m3\n" ..
		     \ "All Files (*.*)\t*.*\n"
endif

let b:undo_ftplugin = "setl com< cms< fo< " ..
		    \ "| unlet! b:browsefilter b:match_words"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
