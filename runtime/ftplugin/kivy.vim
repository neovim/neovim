" Vim filetype plugin
" Language:	Kivy
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2024 Jul 06

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl commentstring=#\ %s

let b:undo_ftplugin = 'setl cms<'
