" Vim filetype plugin file
" Language:		svg
"
" This runtime file is looking for a new maintainer.
"
" Former maintainer:	Dan Sharp
" Last Change:		2009 Jan 20
"			2024 Jan 14 by Vim Project (browsefilter)

if exists("b:did_ftplugin") | finish | endif

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:save_cpo = &cpo
set cpo-=C

" Define some defaults in case the included ftplugins don't set them.
let s:undo_ftplugin = ""
let s:browsefilter = "XML Files (*.xml)\t*.xml\n"
if has("win32")
    let s:browsefilter .= "All Files (*.*)\t*\n"
else
    let s:browsefilter .= "All Files (*)\t*\n"
endif

runtime! ftplugin/xml.vim ftplugin/xml_*.vim ftplugin/xml/*.vim
let b:did_ftplugin = 1

" Override our defaults if these were set by an included ftplugin.
if exists("b:undo_ftplugin")
    let s:undo_ftplugin = b:undo_ftplugin
endif
if exists("b:browsefilter")
    let s:browsefilter = b:browsefilter
endif

" Change the :browse e filter to primarily show xml-related files.
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
    let  b:browsefilter="SVG Files (*.svg)\t*.svg\n" . s:browsefilter
endif

" Undo the stuff we changed.
let b:undo_ftplugin = "unlet! b:browsefilter | " . s:undo_ftplugin

" Restore the saved compatibility options.
let &cpo = s:save_cpo
unlet s:save_cpo
