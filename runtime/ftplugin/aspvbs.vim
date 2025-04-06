" Vim filetype plugin file
" Language:		aspvbs
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
let s:browsefilter = "HTML Files (*.html, *.htm)\t*.htm*\n"
if has("win32")
    let s:browsefilter .= "All Files (*.*)\t*\n"
else
    let s:browsefilter .= "All Files (*)\t*\n"
endif
let s:match_words = ""

runtime! ftplugin/html.vim ftplugin/html_*.vim ftplugin/html/*.vim
let b:did_ftplugin = 1

" Override our defaults if these were set by an included ftplugin.
if exists("b:undo_ftplugin")
    let s:undo_ftplugin = b:undo_ftplugin
endif
if exists("b:browsefilter")
    let s:browsefilter = b:browsefilter
endif
if exists("b:match_words")
    let s:match_words = b:match_words
endif

" ASP:  Active Server Pages (with Visual Basic Script)
" thanks to Gontran BAERTS
if exists("loaded_matchit")
  let s:notend = '\%(\<end\s\+\)\@<!'
  let b:match_ignorecase = 1
  let b:match_words =
  \ s:notend . '\<if\>\%(.\{-}then\s\+\w\)\@!:\<elseif\>:^\s*\<else\>:\<end\s\+\<if\>,' .
  \ s:notend . '\<select\s\+case\>:\<case\>:\<case\s\+else\>:\<end\s\+select\>,' .
  \ '^\s*\<sub\>:\<end\s\+sub\>,' .
  \ '^\s*\<function\>:\<end\s\+function\>,' .
  \ '\<class\>:\<end\s\+class\>,' .
  \ '^\s*\<do\>:\<loop\>,' .
  \ '^\s*\<for\>:\<next\>,' .
  \ '\<while\>:\<wend\>,' .
  \ s:match_words
endif

" Change the :browse e filter to primarily show ASP-related files.
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
    let  b:browsefilter="ASP Files (*.asp)\t*.asp\n" . s:browsefilter
endif

let b:undo_ftplugin = "unlet! b:match_words b:match_ignorecase b:browsefilter | " . s:undo_ftplugin

" Restore the saved compatibility options.
let &cpo = s:save_cpo
unlet s:save_cpo
