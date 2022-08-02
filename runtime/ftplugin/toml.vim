" Vim filetype plugin
" Language:    TOML
" Homepage:    https://github.com/cespare/vim-toml
" Maintainer:  Aman Verma
" Author:      Kevin Ballard <kevin@sb.org>
" Last Change: Sep 21, 2021

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo&vim
let b:undo_ftplugin = 'setlocal commentstring< comments<'

setlocal commentstring=#\ %s
setlocal comments=:#

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: et sw=2 sts=2
