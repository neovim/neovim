" Neovim color file
" Maintainer:	The Neovim Project <https://github.com/neovim/neovim>
" Last Change:	2023 Dec 01

" This is the default color scheme.

" Set 'background' back to the default. The value can't always be estimated
" and is then guessed.
hi clear Normal
set bg&

" Remove all existing highlighting and set the defaults.
hi clear

" Load the syntax highlighting defaults, if it's enabled.
if exists("syntax_on")
  syntax reset
endif

let colors_name = "default"

" vim: sw=2
