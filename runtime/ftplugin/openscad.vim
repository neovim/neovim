" Vim filetype plugin file
" Language:    OpenSCAD (https://openscad.org)
" Maintainer:  Zachary Scheiman <me@zacharyscheiman.com>
" Last Change: 2025 Aug 3

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

" Comments in openscad follow C/C++ syntax
setlocal commentstring=//\ %s

let b:undo_ftplugin = 'setl commentstring<'
