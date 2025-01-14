" Vim filetype plugin
" Language:	EditorConfig
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2025 Jan 10

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl comments=:#,:; commentstring=#\ %s

setl omnifunc=syntaxcomplete#Complete

let b:undo_ftplugin = 'setl com< cms< ofu<'
