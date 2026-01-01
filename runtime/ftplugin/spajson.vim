" Vim filetype plugin
" Language:	SPA JSON
" Maintainer:	David Mandelberg <david@mandelberg.org>
" Last Change:	2025 Mar 22

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:###,:##,:#
setlocal commentstring=#\ %s

let b:undo_ftplugin = "setlocal comments< commentstring<"
