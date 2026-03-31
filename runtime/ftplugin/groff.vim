" Vim syntax file
" Language:  groff(7)
" Maintainer: Eisuke Kawashima ( e.kawaschima+vim AT gmail.com )
" Last Change: 2025 Apr 24
" 2025 Jun 18 by Vim Project: update commentstring option (#17516)

if exists('b:did_ftplugin')
  finish
endif

let b:nroff_is_groff = 1

runtime! ftplugin/nroff.vim

setlocal commentstring=\\#\ %s
setlocal comments=:\\#,:.\\\",:\\\",:'\\\",:'''

let b:undo_ftplugin .= '| unlet! b:nroff_is_groff'
let b:did_ftplugin = 1
