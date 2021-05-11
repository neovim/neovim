" Vim filetype plugin file
" Language:	Modula-3 Quake
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2021 April 15

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=s1:/*,mb:*,ex:*/,:%
setlocal commentstring=%\ %s
setlocal formatoptions-=t formatoptions+=croql

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_words = '\<\%(proc\|if\|foreach\)\>:\<else\>:\<end\>'
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Modula-3 Quake Source Files (*.quake)\t*.quake\n" ..
	\	       "All Files (*.*)\t*.*\n"
endif

let b:undo_ftplugin = "setl fo< com< cms< " ..
      \		      "| unlet! b:browsefilter b:match_words"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
