" Vim indent file
" Language:	HIP (Heterogeneous-compute Interface for Portability)
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2026 Jul 15

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif
let b:did_indent = 1

" It's just like C indenting
setlocal cindent

let b:undo_indent = "setl cin<"
