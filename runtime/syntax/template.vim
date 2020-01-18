" Vim syntax file
" Language:	Generic template
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2019 May 06

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Known template types are very similar to HTML, E.g. golang and "Xfire User
" Interface Template"
" If you know how to recognize a more specific type for *.tmpl suggest a
" change to runtime/scripts.vim.
runtime! syntax/html.vim
