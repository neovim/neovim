" Vim filetype plugin file
" Language:     Pixar Animation's Universal Scene Description format
" Maintainer:   Colin Kennedy <colinvfx@gmail.com>
" Last Change:  2023 May 9
"               2023 Aug 28 by Vim Project (undo_ftplugin)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=#\ %s

let b:undo_ftplugin = "setlocal commentstring<"
