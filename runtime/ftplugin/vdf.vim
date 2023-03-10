" Vim filetype plugin
" Language:	Valve Data Format
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Last Change:	2022 Sep 15

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl comments=:// commentstring=//\ %s
setl foldmethod=syntax

let b:undo_ftplugin = 'setl com< cms< fdm<'
