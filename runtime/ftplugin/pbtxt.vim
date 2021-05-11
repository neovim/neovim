" Vim filetype plugin file
" Language:             Protobuf Text Format
" Maintainer:           Lakshay Garg <lakshayg@outlook.in>
" Last Change:          2020 Nov 17
" Homepage:             https://github.com/lakshayg/vim-pbtxt

if exists("b:did_ftplugin")
  finish
endif

let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal commentstring=#\ %s

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet
