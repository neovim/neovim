" Vim filetype plugin
" Language:	awk, nawk, gawk, mawk
" Maintainer:	Antonio Colombo <azc100@gmail.com>
" Last Change:	2017 Feb 17

" This plugin was prepared by Mark Sikora

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl commentstring<"

setlocal commentstring=#\ %s
