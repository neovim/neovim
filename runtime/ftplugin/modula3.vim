" Vim filetype plugin file
" Language:	Modula-3
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2022 June 12 

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=s0:(*,mb:\ ,ex:*)
setlocal commentstring=(*%s*)
setlocal formatoptions-=t formatoptions+=croql
setlocal suffixesadd+=.m3
setlocal formatprg=m3pp

let b:undo_ftplugin = "setlocal com< cms< fo< fp< sua<"

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_words = '\<REPEAT\>:\<UNTIL\>,' ..
		    \ '\<\%(BEGIN\|CASE\|FOR\|IF\|LOCK\|LOOP\|TRY\|TYPECASE\|WHILE\|WITH\|RECORD\|OBJECT\)\>' ..
		    \	':' ..
		    \	'\<\%(ELSIF\|ELSE\|EXCEPT\|FINALLY\|METHODS\|OVERRIDES\)\>\|\%(^\s*\)\@<=\S.*=>' ..
		    \	':' ..
		    \ '\<END\>,' ..
		    \ '(\*:\*),<\*:\*>'
  let b:undo_ftplugin ..= " | unlet! b:match_words"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Modula-3 Source Files (*.m3)\t*.m3\n" ..
		     \ "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
