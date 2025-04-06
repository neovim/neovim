" Vim syntax file
" Language:	Generic template
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Known template types are very similar to HTML, E.g. golang and "Xfire User
" Interface Template"
" If you know how to recognize a more specific type for *.tmpl suggest a
" change to runtime/scripts.vim.
runtime! syntax/html.vim
