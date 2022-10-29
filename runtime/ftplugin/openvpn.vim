" Vim filetype plugin
" Language:	OpenVPN
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Last Change:	2022 Oct 16

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal iskeyword+=-,.,/
setlocal comments=:#,:; commentstring=#%s

let b:undo_ftplugin = 'setl isk< com< cms<'
