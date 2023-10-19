" Vim filetype plugin file
" Language:	JSON5
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2023 Oct 19

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setl fo< com< cms<"

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "JSON5 Files (*.json5)\t*.json5\n" ..
	\	       "JSON Files (*.json)\t*.json\n" ..
	\	       "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
