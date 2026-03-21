" Vim filetype plugin
" Language:	Bicep
" Maintainer:	Scott McKendry <me@scottmckendry.tech>
" Last Change:	2025 Dec 27

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s

let b:undo_ftplugin = "setlocal comments< commentstring<"
