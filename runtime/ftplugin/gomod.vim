" Vim filetype plugin file
" Language:    go module file
" Maintainer:  YU YUK KUEN <yukkuen.yu719@gmail.com>
" Last Change: 2024-06-21
" 2024 Jul 16 by Vim Project (noexpandtab)

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal noexpandtab
setlocal formatoptions-=t formatoptions-=c
setlocal commentstring=//\ %s

let b:undo_ftplugin = 'setl et< fo< cms<'
