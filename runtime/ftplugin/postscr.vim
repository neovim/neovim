" Vim filetype plugin file
" Language:	PostScript
" Maintainer:	Mike Williams <mrw@eandem.co.uk>
" Last Change:  24th April 2012

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

" PS comment formatting
setlocal comments=b:%
setlocal formatoptions-=t formatoptions+=rol

" Define patterns for the matchit macro
if !exists("b:match_words")
  let b:match_ignorecase = 0
  let b:match_words = '<<:>>,\<begin\>:\<end\>,\<save\>:\<restore\>,\<gsave\>:\<grestore\>'
endif

" Define patterns for the browse file filter
if has("gui_win32") && !exists("b:browsefilter")
  let b:browsefilter = "PostScript Files (*.ps)\t*.ps\n" .
    \ "EPS Files (*.eps)\t*.eps\n" .
    \ "All Files (*.*)\t*.*\n"
endif

let b:undo_ftplugin = "setlocal comments< formatoptions<"
    \ . "| unlet! b:browsefiler b:match_ignorecase b:match_words"

let &cpo = s:cpo_save
unlet s:cpo_save
