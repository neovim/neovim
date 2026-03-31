" Vim indent file
" Language:	m17n database
" Maintainer:	David Mandelberg <david@mandelberg.org>
" Last Change:	2025 Feb 21

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal autoindent
setlocal nosmartindent

let b:undo_indent = "setlocal autoindent< smartindent<"
