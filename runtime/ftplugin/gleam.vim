" Vim filetype plugin file
" Language:            Gleam
" Maintainer:          Kirill Morozov <kirill@robotix.pro>
" Previous Maintainer: Trilowy (https://github.com/trilowy)
" Last Change:         2025 Apr 16

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=://,:///,:////
setlocal commentstring=//\ %s
setlocal formatprg=gleam\ format\ --stdin

let b:undo_ftplugin = "setlocal com< cms< fp<"

if get(g:, "gleam_recommended_style", 1)
  setlocal expandtab
  setlocal shiftwidth=2
  setlocal softtabstop=2
  let b:undo_ftplugin ..= " | setlocal et< sw< sts<"
endif

" vim: sw=2 sts=2 et
