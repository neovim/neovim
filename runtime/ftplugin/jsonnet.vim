" Vim filetype plugin
" Language:        Jsonnet
" Maintainer:      Cezary Drożak <cezary@drozak.net>
" URL:             https://github.com/google/vim-jsonnet
" Last Change:     2022-09-08

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

setlocal commentstring=//\ %s

let b:undo_ftplugin = "setlocal commentstring<"
