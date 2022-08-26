" Vim filetype plugin file
" Language:	HMTL Tidy Configuration
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2020 Sep 4

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:#,://
setlocal commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "HTML Tidy Files (tidyrc, .tidyrc, tidy.conf)\ttidyrc;.tidyrc;tidy.conf\n" .
		     \ "HTML Files (*.html, *.htm)\t*.html;*.htm\n" .
		     \ "XHTML Files (*.xhtml, *.xhtm)\t*.xhtml;*.xhtm\n" .
		     \ "XML Files (*.xml)\t*.xml\n" .
		     \ "All Files (*.*)\t*.*\n"
endif

let b:undo_ftplugin = "setl fo< com< cms<" .
		    \ " | unlet! b:browsefilter"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8
