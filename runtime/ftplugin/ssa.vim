" Vim filetype plugin
" Language:	SubStation Alpha
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Last Change:	2022 Oct 10

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:;,:!: commentstring=;\ %s

let b:undo_ftplugin = 'setl com< cms<'
