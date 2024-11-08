" Vim filetype plugin file
" Language:    Gleam
" Maintainer:  Trilowy (https://github.com/trilowy)
" Last Change: 2024 Oct 13

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=://,:///,:////
setlocal commentstring=//\ %s

let b:undo_ftplugin = "setlocal comments< commentstring<"

" vim: sw=2 sts=2 et
