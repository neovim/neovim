" Vim filetype plugin file
" Language:	XCompose
" Maintainer:	ObserverOfTime <chronobserver@disroot.org
" Last Change:	2023 Nov 09

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl comments=:# commentstring=#\ %s

let b:undo_ftplugin = 'setl com< cms<'
