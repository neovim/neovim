" Vim filetype plugin file
" Language:	hg (Mercurial) commit file
" Maintainer:	Ken Takata <kentkt at csc dot jp>
" Last Change:	2016 Jan 6
" Filenames:	hg-editor-*.txt
" License:	VIM License
" URL:		https://github.com/k-takata/hg-vim

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal nomodeline

let b:undo_ftplugin = 'setl modeline<'
