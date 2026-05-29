" Vim filetype plugin file
" Language:     Tolk
" Maintainer:   redavy <hello.redavy@proton.me>
" Upstream:     https://github.com/redavy/vim-tolk
" Last Update:  24 May 2026

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=//\ %s

if get(g:, 'tolk_recommended_style', get(g:, 'recommended_style', 1))
  setlocal tabstop=2
  setlocal shiftwidth=2
  setlocal expandtab
  setlocal softtabstop=2
  setlocal cindent
endif

let b:undo_ftplugin = "setlocal commentstring< tabstop< shiftwidth< expandtab< softtabstop< cindent<"
