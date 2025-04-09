" Vim filetype plugin file
" Language:             Remind - a sophisticated calendar and alarm
" Maintainer:           Joe Reynolds <joereynolds952@gmail.com>
" Latest Revision:      2025 April 08
" License:              Vim (see :h license)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:# commentstring=#\ %s

let b:undo_ftplugin = "setl cms< com<"
