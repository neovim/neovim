" Vim filetype plugin
" Language:    TOML
" Homepage:    https://github.com/cespare/vim-toml
" Maintainer:  Aman Verma
" Author:      Lily Ballard <lily@ballards.net>
" Last Change: May 5, 2025

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo&vim
let b:undo_ftplugin = 'setlocal commentstring< comments< iskeyword<'

setlocal commentstring=#\ %s
setlocal comments=:#
setlocal iskeyword+=-

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: et sw=2 sts=2
