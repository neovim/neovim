" Vim filetype plugin
" Language:	Haml
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2019 Dec 05
"		2024 Jan 14 by Vim Project (browsefilter)

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

let s:save_cpo = &cpo
set cpo-=C

" Define some defaults in case the included ftplugins don't set them.
let s:undo_ftplugin = ""
if has("win32")
  let s:browsefilter = "All Files (*.*)\t*\n"
else
  let s:browsefilter = "All Files (*)\t*\n"
endif
let s:match_words = ""

runtime! ftplugin/html.vim ftplugin/html_*.vim ftplugin/html/*.vim
unlet! b:did_ftplugin
set matchpairs-=<:>

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

runtime! ftplugin/ruby.vim ftplugin/ruby_*.vim ftplugin/ruby/*.vim
let b:did_ftplugin = 1

let &l:define .= empty(&l:define ? '' : '\|') . '^\s*\%(%\w*\)\=\%(\.[[:alnum:]_-]\+\)*#'

" Combine the new set of values with those previously included.
if exists("b:undo_ftplugin")
  let s:undo_ftplugin = b:undo_ftplugin . " | " . s:undo_ftplugin
endif
if exists ("b:browsefilter")
  let s:browsefilter = substitute(b:browsefilter,'\cAll Files (.*)\t\*\n','','') . s:browsefilter
endif
if exists("b:match_words")
  let s:match_words = b:match_words . ',' . s:match_words
endif

" Change the browse dialog on Win32 and GTK to show mainly Haml-related files
if has("gui_win32") || has("gui_gtk")
  let b:browsefilter="Haml Files (*.haml)\t*.haml\nSass Files (*.sass)\t*.sass\n" . s:browsefilter
endif

" Load the combined list of match_words for matchit.vim
if exists("loaded_matchit")
  let b:match_words = s:match_words
endif

setlocal comments= commentstring=-#\ %s

let b:undo_ftplugin = "setl def< cms< com< " .
      \ " | unlet! b:browsefilter b:match_words | " . s:undo_ftplugin

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set sw=2:
