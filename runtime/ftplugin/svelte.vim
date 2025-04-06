" Vim filetype plugin
" Language:	svelte
" Maintainer:	Igor Lacerda <igorlafarsi@gmail.com>
" Last Change:	2024 Jun 09

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl commentstring=<!--\ %s\ -->

let b:undo_ftplugin = 'setl cms<'
