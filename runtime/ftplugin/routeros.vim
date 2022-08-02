" Vim filetype plugin file
" Language:	MikroTik RouterOS Script
" Maintainer:	zainin <z@wintr.dev>
" Last Change:	2021 Nov 14

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo-=C

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setlocal com< cms< fo<"

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "RouterOS Script Files (*.rsc)\t*.rsc\n" ..
	\	       "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:save_cpo
unlet! s:save_cpo

" vim: nowrap sw=2 sts=2 ts=8 noet:
