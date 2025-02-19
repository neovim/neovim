" Vim filetype plugin
" Language:	Dockerfile
" Maintainer:   Honza Pokorny <http://honza.ca>
" Last Change:	2024 Dec 20

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

setlocal commentstring=#\ %s

let b:undo_ftplugin = "setl commentstring<"
