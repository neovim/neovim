" Vim filetype plugin file
" Language:            Gleam
" Maintainer:          Kirill Morozov <kirill@robotix.pro>
" Previous Maintainer: Trilowy (https://github.com/trilowy)
" Last Change:         2025-04-12

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=://,:///,:////
setlocal commentstring=//\ %s
setlocal expandtab
setlocal formatprg=gleam\ format\ --stdin
setlocal shiftwidth=2
setlocal softtabstop=2

let b:undo_ftplugin = "setlocal com< cms< fp< et< sw< sts<"

" vim: sw=2 sts=2 et
