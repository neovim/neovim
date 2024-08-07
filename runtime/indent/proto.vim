" Vim indent file
" Language:	Protobuf
" Maintainer:	David Pedersen <limero@me.com>
" Last Change:	2024 Aug 07

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

" Protobuf is like indenting C
setlocal cindent
setlocal expandtab
setlocal shiftwidth=2

let b:undo_indent = "setlocal cindent< expandtab< shiftwidth<"

" vim: sw=2 sts=2 et
