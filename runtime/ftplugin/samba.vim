" Vim filetype plugin
" Language:     smb.conf(5) configuration file
" Maintainer:	Matt Perry <matt@mattperry.com>
" Last Change:	2025 Feb 13

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:;,:# commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = 'setl com< cms< fo<'
