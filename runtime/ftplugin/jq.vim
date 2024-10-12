" Vim compiler file
" Language:	jq
" Maintainer:	Vito <vito.blog@gmail.com>
" Last Change:	2024 Apr 29
" 		2024 May 23 by Riley Bruins <ribru17@gmail.com> ('commentstring')
" 		2024 Oct 04 by Konfekt (unset compiler)
" Upstream: https://github.com/vito-c/jq.vim

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal include=^\\s*\\%(import\\\|include\\)
setlocal commentstring=#\ %s

let b:undo_ftplugin = 'setl commentstring< include<'

if !exists('current_compiler')
  let b:undo_ftplugin ..= "| compiler make"
  compiler jq
endif

