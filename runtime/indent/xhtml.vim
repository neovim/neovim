" Vim indent file
" Language:	XHTML
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif

" Handled like HTML for now.
runtime! indent/html.vim
