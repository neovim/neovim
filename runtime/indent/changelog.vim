" Vim indent file
" Language:	generic Changelog file
" Maintainer:	noone
" Last Change:	2005 Mar 29

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif
let b:did_indent = 1

setlocal ai

let b:undo_indent = "setl ai<"
