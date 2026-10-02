" Vim filetype plugin
" Language:	git ignore
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Last Change:	2022 Sep 10
" 2026 Aug 28 by Vim project: update b:undo_ftplugin #21180

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl comments=:# commentstring=#\ %s

let b:undo_ftplugin = get(b:, 'undo_ftplugin', '')
if !empty(b:undo_ftplugin)
  let b:undo_ftplugin .= ' | '
endif
let b:undo_ftplugin .= 'setlocal comments< commentstring<'
