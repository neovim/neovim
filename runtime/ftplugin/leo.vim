" Vim filetype plugin
" Language:	Leo
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2024 Nov 03

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl comments=:// commentstring=//\ %s

let b:undo_ftplugin = 'setl com< cms<'
