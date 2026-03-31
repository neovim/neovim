" Vim filetype plugin
" Language:    crontab
" Maintainer:  Keith Smiley <keithbsmiley@gmail.com>
" Last Change: 2022 Sep 11

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl commentstring<"

setlocal commentstring=#\ %s
