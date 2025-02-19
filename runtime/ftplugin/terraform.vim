" Vim filetype plugin
" Language: terraform
" Maintainer: Janno Tjarks (janno.tjarks@mailbox.org)
" Last Change: 2024 Jul 3

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=#\ %s
setlocal comments=://,:#

let b:undo_ftplugin = "setlocal commentstring< comments<"
