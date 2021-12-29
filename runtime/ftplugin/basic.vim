" Vim filetype plugin file
" Language:	BASIC
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2015 Jan 10

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:REM,:'
setlocal commentstring='\ %s
setlocal formatoptions-=t formatoptions+=croql

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "BASIC Source Files (*.bas)\t*.bas\n" .
		     \ "All Files (*.*)\t*.*\n"
endif

let b:undo_ftplugin = "setl fo< com< cms< sua<" .
		    \ " | unlet! b:browsefilter"

let &cpo = s:cpo_save
unlet s:cpo_save
