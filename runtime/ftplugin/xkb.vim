" Vim filetype plugin
" Language:    xkb (X keyboard extension)
" Maintainer:  The Vim Project <https://github.com/vim/vim>
" Last Change: 2026 Mar 01

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl comments=://
setl commentstring=//\ %s

let b:undo_ftplugin = 'setl com< cms<'
