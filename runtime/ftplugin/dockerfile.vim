" Vim filetype plugin
" Language:	Dockerfile
" Maintainer:   Honza Pokorny <http://honza.ca>
" Last Change:	2014 Aug 29

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl commentstring<"

setlocal commentstring=#\ %s
