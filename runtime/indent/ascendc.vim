" Vim indent file
" Language:	Ascend C
" Maintainer:	Yinzuo Jiang <jiangyinzuo@foxmail.com>
" Last Change:	2026 Nov 5

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif
let b:did_indent = 1

" It's just like C indenting
setlocal cindent

let b:undo_indent = "setl cin<"
