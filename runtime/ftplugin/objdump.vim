" Vim filetype plugin file
" Language:     Objdump
" Maintainer:   Colin Kennedy <colinvfx@gmail.com>
" Last Change:  2023 October 25

if exists("b:did_ftplugin")
  finish
endif

let b:did_ftplugin = 1

let b:undo_ftplugin = "setlocal cms<"

setlocal commentstring=#\ %s
