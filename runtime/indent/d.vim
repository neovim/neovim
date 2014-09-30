" Vim indent file for the D programming language (version 0.137).
"
" Language:	D
" Maintainer:	Jason Mills<jmills@cs.mun.ca>
" Last Change:	2005 Nov 22
" Version:	0.1
"
" Please email me with bugs, comments, and suggestion. Put vim in the subject
" to ensure the email will not be marked has spam.
"

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif

let b:did_indent = 1

" D indenting is a lot like the built-in C indenting.
setlocal cindent

" vim: ts=8 noet
