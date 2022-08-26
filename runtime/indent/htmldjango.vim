" Vim indent file
" Language:	Django HTML template
" Maintainer:	Dave Hodder <dmh@dmh.org.uk>
" Last Change:	2007 Jan 25

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif

" Use HTML formatting rules.
runtime! indent/html.vim
