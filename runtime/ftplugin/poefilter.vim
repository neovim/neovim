" Vim filetype plugin
" Language:	PoE item filter
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Last Change:	2022 Oct 07

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:# commentstring=#\ %s

let b:undo_ftplugin = 'setl com< cms<'
