" Vim indent file
" Language:    Fennel
" Maintainer:  Gregory Anders <greg[NOSPAM]@gpanders.com>
" Last Change: 2022 Apr 20

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif

" Use the Lisp indenting
runtime! indent/lisp.vim
