" Vim syntax file
" Language:	Godoc (generated documentation for go)
" Maintainer:	David Barnett (https://github.com/google/vim-ft-go)
" Last Change:	2014 Aug 16

if exists('b:current_syntax')
  finish
endif

syn case match
syn match godocTitle "^\([A-Z][A-Z ]*\)$"

command -nargs=+ HiLink hi def link <args>

HiLink godocTitle Title

delcommand HiLink

let b:current_syntax = 'godoc'

" vim: sw=2 sts=2 et
