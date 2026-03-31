" Vim filetype plugin file
" Language:	occam
" Copyright:	Christian Jacobsen <clj3@kent.ac.uk>, Mario Schweigler <ms44@kent.ac.uk>
" Maintainer:	Mario Schweigler <ms44@kent.ac.uk>
" Last Change:	23 April 2003
" 2024 Jan 14 by Vim Project (browsefilter)
" 2025 Jun 08 by Riley Bruins <ribru17@gmail.com> ('commentstring')

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1
let s:keepcpo= &cpo
set cpo&vim

"{{{  Indent settings
" Set shift width for indent
setlocal shiftwidth=2
" Set the tab key size to two spaces
setlocal softtabstop=2
" Let tab keys always be expanded to spaces
setlocal expandtab
"}}}

"{{{  Formatting
" Break comment lines and insert comment leader in this case
setlocal formatoptions-=t formatoptions+=cql
setlocal comments+=:--
setlocal commentstring=--\ %s
" Maximum length of comments is 78
setlocal textwidth=78
"}}}

"{{{  File browsing filters
" Win32 and GTK can filter files in the browse dialog
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "All Occam Files (*.occ, *.inc)\t*.occ;*.inc\n" .
	\ "Occam Include Files (*.inc)\t*.inc\n" .
	\ "Occam Source Files (*.occ)\t*.occ\n"
  if has("win32")
    let b:browsefilter .= "All Files (*.*)\t*\n"
  else
    let b:browsefilter .= "All Files (*)\t*\n"
  endif
endif
"}}}

"{{{  Undo settings
let b:undo_ftplugin = "setlocal shiftwidth< softtabstop< expandtab<"
	\ . " formatoptions< comments< commentstring< textwidth<"
	\ . "| unlet! b:browsefilter"
"}}}

let &cpo = s:keepcpo
unlet s:keepcpo
