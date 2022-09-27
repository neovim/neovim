" Vim filetype plugin
" Language:	Chatito
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Last Change:	2022 Sep 19

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:#,:// commentstring=#\ %s
" indent of 4 spaces is mandated by the spec
setlocal expandtab softtabstop=4 shiftwidth=4

let b:undo_ftplugin = 'setl com< cms< et< sts< sw<'
