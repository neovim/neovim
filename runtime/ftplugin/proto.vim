" Vim filetype plugin
" Language:	Protobuf
" Maintainer:	David Pedersen <limero@me.com>
" Last Change:	2024 Dec 09

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal formatoptions-=t formatoptions+=croql

setlocal comments=s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s

let b:undo_ftplugin = "setlocal formatoptions< comments< commentstring<"

" vim: sw=2 sts=2 et
