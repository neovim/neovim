" Vim filetype plugin file
" Language:	Expect
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2022 Jul 16

if exists("b:did_ftplugin")
  finish
endif

" Syntax is similar to Tcl
runtime! ftplugin/tcl.vim

let s:cpo_save = &cpo
set cpo&vim

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Expect Command Files (*.exp)\t*.exp\n" ..
	\	       "All Files (*.*)\t*.*\n"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8
