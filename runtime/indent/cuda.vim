" Vim indent file
" Language:	CUDA
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2008 Nov 29

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif
let b:did_indent = 1

" It's just like C indenting
setlocal cindent

let b:undo_indent = "setl cin<"
