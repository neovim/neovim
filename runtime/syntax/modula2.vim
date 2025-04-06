" Vim syntax file
" Language:		Modula-2
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	pf@artcom0.north.de (Peter Funk)
" Last Change:		2024 Jan 04

if exists("b:current_syntax")
  finish
endif

let dialect = modula2#GetDialect()
exe "runtime! syntax/modula2/opt/" .. dialect .. ".vim"

let b:current_syntax = "modula2"

" vim: nowrap sw=2 sts=2 ts=8 noet:
