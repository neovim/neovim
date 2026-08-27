" Vim syntax file
" Language:		Directory listing
" Maintainer:		The Nvim Project <https://github.com/neovim/neovim>

if exists("b:current_syntax")
  finish
endif

syn match directoryDirectory ".*/$"

hi def link directoryDirectory Directory

let b:current_syntax = "directory"
