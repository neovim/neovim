" Vim filetype plugin file
" Language:	Modula-2
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Jan 14
" 		2024 May 23 by Riley Bruins <ribru17@gmail.com> ('commentstring')

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let s:dialect = modula2#GetDialect()

if s:dialect ==# "r10"
  setlocal comments=s:(*,m:\ ,e:*),:!
  setlocal commentstring=!\ %s
else
  setlocal commentstring=(*\ %s\ *)
  setlocal comments=s:(*,m:\ ,e:*)
endif
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setl com< cms< fo<"

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0
  " the second branch of the middle pattern is intended to match CASE labels
  let b:match_words = '\<REPEAT\>:\<UNTIL\>,' ..
	\	      '\<\%(BEGIN\|CASE\|FOR\|IF\|LOOP\|WHILE\|WITH\|RECORD\)\>' ..
	\		':' ..
	\		'\<\%(ELSIF\|ELSE\)\>\|\%(^\s*\)\@<=\w\+\%(\s*\,\s*\w\+\)\=\s*\:=\@!' ..
	\		':' ..
	\	      '\<END\>,' ..
	\	      '(\*:\*),<\*:\*>'
  let b:match_skip = 's:Comment\|Pragma'
  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_skip b:match_words"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Modula-2 Source Files (*.def, *.mod)\t*.def;*.mod\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
