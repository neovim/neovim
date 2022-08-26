" Vim indent file
" Language:	Pyrex
" Maintainer:	Marco Barisione <marco.bari@people.it>
" URL:		http://marcobari.altervista.org/pyrex_vim.html
" Last Change:	2005 Jun 24

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif

" Use Python formatting rules
runtime! indent/python.vim
