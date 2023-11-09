" Vim filetype plugin file
" Language:	Wget configuration file (/etc/wgetrc ~/.wgetrc)
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2022 Apr 28

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:#,://
setlocal commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setl fo< com< cms<"

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Wget Configuration File (wgetrc, .wgetrc)\twgetrc;.wgetrc\n" ..
	\	       "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8
