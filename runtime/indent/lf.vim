" Vim indent file
" Language: lf file manager configuration file (lfrc)
" Maintainer: Andis Sprinkis <andis@sprinkis.com>
" URL: https://github.com/andis-sprinkis/lf-vim
" Last Change: 26 Oct 2025

if exists("b:did_indent") | finish | endif

" Correctly indent embedded shell commands.
runtime! indent/sh.vim
