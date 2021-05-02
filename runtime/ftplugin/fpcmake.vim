" Vim filetype plugin file
" Language:	Free Pascal Makefile Generator
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2021 Apr 23

if exists("b:did_ftplugin")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

runtime! ftplugin/make.vim

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Free Pascal Makefile Definition Files (*.fpc)\t*.fpc\n" ..
		     \ "All Files (*.*)\t*.*\n"
endif

let b:undo_ftplugin = b:undo_ftplugin .. " | unlet! b:browsefilter"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
