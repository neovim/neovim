" Vim filetype plugin file
" Language:	xhtml
" Maintainer:	Dan Sharp <dwsharp at users dot sourceforge dot net>
" Last Changed: 20 Jan 2009
" URL:		http://dwsharp.users.sourceforge.net/vim/ftplugin

if exists("b:did_ftplugin") | finish | endif

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:save_cpo = &cpo
set cpo-=C

" Define some defaults in case the included ftplugins don't set them.
let s:undo_ftplugin = ""
let s:browsefilter = "HTML Files (*.html, *.htm)\t*.html;*.htm\n" .
	    \	     "XML Files (*.xml)\t*.xml\n" .
	    \	     "All Files (*.*)\t*.*\n"
let s:match_words = ""

runtime! ftplugin/xml.vim ftplugin/xml_*.vim ftplugin/xml/*.vim
unlet b:did_ftplugin

" Override our defaults if these were set by an included ftplugin.
if exists("b:undo_ftplugin")
    let s:undo_ftplugin = b:undo_ftplugin
    unlet b:undo_ftplugin
endif
if exists("b:browsefilter")
    let s:browsefilter = b:browsefilter
    unlet b:browsefilter
endif
if exists("b:match_words")
    let s:match_words = b:match_words
    unlet b:match_words
endif

runtime! ftplugin/html.vim ftplugin/html_*.vim ftplugin/html/*.vim
let b:did_ftplugin = 1

" Combine the new set of values with those previously included.
if exists("b:undo_ftplugin")
    let s:undo_ftplugin = b:undo_ftplugin . " | " . s:undo_ftplugin
endif
if exists("b:browsefilter")
    let s:browsefilter = b:browsefilter . s:browsefilter
endif
if exists("b:match_words")
    let s:match_words = b:match_words . "," . s:match_words
endif

" Load the combined list of match_words for matchit.vim
if exists("loaded_matchit")
    let b:match_words = s:match_words
endif

" Change the :browse e filter to primarily show tcsh-related files.
if has("gui_win32")
    let  b:browsefilter="XHTML files (*.xhtml, *.xhtm)\t*.xhtml;*.xhtm\n" . s:browsefilter
endif

" Undo the stuff we changed.
let b:undo_ftplugin = "unlet! b:browsefilter b:match_words | " . s:undo_ftplugin

" Restore the saved compatibility options.
let &cpo = s:save_cpo
unlet s:save_cpo
