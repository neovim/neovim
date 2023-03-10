" Vim filetype plugin
" Language:	git attributes
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Last Change:	2022 Sep 08

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl comments=:# commentstring=#\ %s

let b:undo_ftplugin = 'setl com< cms<'
