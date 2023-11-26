" Vim filetype plugin file
" Language:             Protobuf Text Format
" Maintainer:           Lakshay Garg <lakshayg@outlook.in>
" Last Change:          2020 Nov 17
"                       2023 Aug 28 by Vim Project (undo_ftplugin)
" Homepage:             https://github.com/lakshayg/vim-pbtxt

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=#\ %s

let b:undo_ftplugin = "setlocal commentstring<"

" vim: nowrap sw=2 sts=2 ts=8 noet
