" Vim filetype plugin file
" Language:	Nvidia PTX (Parellel Thread Execution)
" Maintainer:	Yinzuo Jiang <jiangyinzuo@foxmail.com>
" Last Change:	2024-12-05

if exists("b:did_ftplugin")
  finish
endif

let b:did_ftplugin = 1

" Comments in PTX follow C/C++ syntax
" See: https://docs.nvidia.com/cuda/parallel-thread-execution/#syntax
setlocal commentstring=//\ %s

let b:undo_ftplugin = 'setl commentstring<'
