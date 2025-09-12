" Vim filetype plugin file
" Language:		mbsync configuration file
" Maintainer:		Pierrick Guillaume <pguillaume@fymyte.com>
" Last Change:		2025 Apr 13

if (exists('b:did_ftplugin'))
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setlocal commentstring<"

setlocal commentstring=#\ %s
