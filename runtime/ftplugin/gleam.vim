" Vim filetype plugin file
" Language:            Gleam
" Maintainer:          Kirill Morozov <kirill@robotix.pro>
" Previous Maintainer: Trilowy (https://github.com/trilowy)
" Based On:            https://github.com/gleam-lang/gleam.vim
" Last Change:         2025 Apr 21

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:////,:///,://
setlocal commentstring=//\ %s
setlocal formatprg=gleam\ format\ --stdin
setlocal suffixesadd=.gleam
let b:undo_ftplugin = "setlocal com< cms< fp< sua<"

if get(g:, "gleam_recommended_style", 1)
  setlocal expandtab
  setlocal shiftwidth=2
  setlocal smartindent
  setlocal softtabstop=2
  setlocal tabstop=2
  let b:undo_ftplugin ..= " | setlocal et< sw< si< sts< ts<"
endif

if !exists('current_compiler')
  compiler gleam_build
  let b:undo_ftplugin ..= "| compiler make"
endif

" vim: sw=2 sts=2 et
