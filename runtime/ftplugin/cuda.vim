" Vim filetype plugin
" Language:	CUDA
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2024 Jul 29

if exists('b:did_ftplugin')
  finish
endif

" Behaves mostly just like C++
runtime! ftplugin/cpp.vim
