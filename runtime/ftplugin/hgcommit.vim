" Vim filetype plugin file
" Language:	hg (Mercurial) commit file
" Maintainer:	Ken Takata <kentkt at csc dot jp>
" Last Change:	2025 Jun 8
" Filenames:	hg-editor-*.txt
" License:	VIM License
" URL:		https://github.com/k-takata/hg-vim
" 2025 Jun 18 by Vim Project: update commentstring option (#17480)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal nomodeline

setlocal comments=:HG\:
setlocal commentstring=HG:\ %s

let b:undo_ftplugin = 'setl modeline< com< cms<'
