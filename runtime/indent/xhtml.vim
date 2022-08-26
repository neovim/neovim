" Vim indent file
" Language:	XHTML
" Maintainer:	Bram Moolenaar <Bram@vim.org> (for now)
" Last Change:	2005 Jun 24

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif

" Handled like HTML for now.
runtime! indent/html.vim
