" Vim compiler file
" Language:	jq
" Maintainer:	Vito <vito.blog@gmail.com>
" Last Change:	2024 Apr 29
" 		2024 May 23 by Riley Bruins <ribru17@gmail.com> ('commentstring')
" Upstream: https://github.com/vito-c/jq.vim

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal include=^\\s*\\%(import\\\|include\\)
setlocal commentstring=#\ %s
compiler jq

let b:undo_ftplugin = 'setl commentstring< include<'
