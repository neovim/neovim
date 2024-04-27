" Vim compiler file
" Language:	jq
" Maintainer:	Vito <vito.blog@gmail.com>
" Last Change:	2024 Apr 17
" Upstream: https://github.com/vito-c/jq.vim

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = 'setl commentstring<'

setlocal commentstring=#%s
compiler jq

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
