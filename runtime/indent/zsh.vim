" Vim indent file
" Language:             Zsh shell script
" Maintainer:           Christian Brabandt <cb@256bit.org>
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2015-05-29
" License:              Vim (see :h license)
" Repository:           https://github.com/chrisbra/vim-zsh

if exists("b:did_indent")
  finish
endif

" Same as sh indenting for now.
runtime! indent/sh.vim
