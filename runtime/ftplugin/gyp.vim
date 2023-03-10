" Vim filetype plugin
" Language:	GYP
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Last Change:	2022 Sep 27

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal formatoptions-=t
setlocal commentstring=#\ %s comments=b:#,fb:-

let b:undo_ftplugin = 'setlocal fo< cms< com<'
