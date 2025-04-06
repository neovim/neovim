" Vim filetype plugin
" Language:	Nu
" Maintainer:	Marc Jakobi <marc@jakobi.dev>
" Last Change:	2024 Aug 31

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=#\ %s

let b:undo_ftplugin = 'setl com<'
