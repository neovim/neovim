" Vim filetype plugin file
" Language:	Modula-3 Makefile
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2021 April 15

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

runtime! ftplugin/m3quake.vim

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Modula-3 Makefile (m3makefile m3overrides)\tm3makefile;m3overrides\n" ..
	\	       "All Files (*.*)\t*.*\n"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
