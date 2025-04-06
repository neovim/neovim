" Vim indent file placeholder
" Language:	Vue
" Maintainer:	None, please volunteer if you have a real Vue indent script
" Last Change:	2022 Dec 24

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif
" don't set b:did_indent, otherwise html indenting won't be activated
" let b:did_indent = 1

" Html comes closest
runtime! indent/html.vim
