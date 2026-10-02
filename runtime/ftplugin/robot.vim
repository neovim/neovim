" Vim filetype plugin
" Language:	Robot Framework
" Maintainer:	Dawid Dziurla (github.com/dawidd6)
" Last Change:	2026 Sep 04

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
