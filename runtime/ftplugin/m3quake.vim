" Vim filetype plugin file
" Language:	Modula-3 Quake
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2022 June 12

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=s1:/*,mb:*,ex:*/,:%
setlocal commentstring=%\ %s
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setl fo< com< cms<"

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_words = '\<\%(proc\|if\|foreach\)\>:\<else\>:\<end\>'
  let b:undo_ftplugin ..= " | unlet! b:match_words"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Modula-3 Quake Source Files (*.quake)\t*.quake\n" ..
	\	       "All Files (*.*)\t*.*\n"
  let b:m3quake_set_browsefilter = 1
  let b:undo_ftplugin ..= " | unlet! b:browsefilter b:m3quake_set_browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
