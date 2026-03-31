" Vim filetype plugin
" Language:	kitty
" Maintainer:	Arvin Verain <arvinverain@proton.me>
" Last Change:	2026 Jan 22

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl comments=:# commentstring=#\ %s formatoptions-=t formatoptions+=rol

let b:undo_ftplugin = 'setl com< cms< fo<'
