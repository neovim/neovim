" Vim indent file
" Language:	Ch
" Maintainer:	SoftIntegration, Inc. <info@softintegration.com>
" URL:		http://www.softintegration.com/download/vim/indent/ch.vim
" Last change:	2006 Apr 30
" 		2023 Aug 28 by Vim Project (undo_indent)
"		Created based on cpp.vim
"
" Ch is a C/C++ interpreter with many high level extensions


" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif
let b:did_indent = 1

" Ch indenting is built-in, thus this is very simple
setlocal cindent

let b:undo_indent = "setlocal cindent<"
