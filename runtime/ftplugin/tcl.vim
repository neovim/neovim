" Vim filetype plugin file
" Language:         Tcl
" Maintainer:       Robert L Hicks <sigzero@gmail.com>
" Latest Revision:  2009-05-01
"                   2024 Jan 14 by Vim Project (browsefilter)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:cpo_save = &cpo
set cpo-=C

setlocal comments=:#
setlocal commentstring=#%s
setlocal formatoptions+=croql

" Change the browse dialog on Windows to show mainly Tcl-related files
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
    let b:browsefilter = "Tcl Source Files (*.tcl)\t*.tcl\n" .
                \ "Tcl Test Files (*.test)\t*.test\n"
    if has("win32")
        let b:browsefilter .= "All Files (*.*)\t*\n"
    else
        let b:browsefilter .= "All Files (*)\t*\n"
    endif
endif

"-----------------------------------------------------------------------------

" Undo the stuff we changed.
let b:undo_ftplugin = "setlocal fo< com< cms< inc< inex< def< isf< kp<" .
	    \	      " | unlet! b:browsefilter"

" Restore the saved compatibility options.
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set et ts=4 sw=4 tw=78:
