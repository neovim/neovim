" Vim indent file
" Language:            Scheme
" Last Change:         2024 Jun 21
" Maintainer:          Evan Hanson <evhan@foldling.org>
" Previous Maintainer: Sergey Khorev <sergey.khorev@gmail.com>
" Repository:          https://git.foldling.org/vim-scheme.git
" URL:                 https://foldling.org/vim/indent/scheme.vim

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif

" Use the Lisp indenting
runtime! indent/lisp.vim
