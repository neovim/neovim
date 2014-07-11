" Vim indent file
" Language:    ANT files
" Maintainer:  David Fishburn <fishburn@ianywhere.com>
" Last Change: Thu May 15 2003 10:02:54 PM

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif

" Use XML formatting rules
runtime! indent/xml.vim
