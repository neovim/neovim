" Vim filetype plugin file
" Language:	sed
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2020 Apr 1

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setl com< cms< fo<"

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "sed Script Files (*.sed)\t*.sed\n" ..
	\	       "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8
