" Vim filetype plugin
" Language:	PyPA manifest
" Maintainer:	ObserverOfTime <chronobserver@disroot.org> (invalid)
" Last Change:	2023 Aug 08

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl comments=:# commentstring=#\ %s

let b:undo_ftplugin = 'setl com< cms<'
