" Vim syntax file
" Language:		Modula-2
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	pf@artcom0.north.de (Peter Funk)
" Last Change:		2024 Jan 04
" 2025 Apr 16 by Vim Project (set 'cpoptions' for line continuation, #17121)

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let dialect = modula2#GetDialect()
exe "runtime! syntax/modula2/opt/" .. dialect .. ".vim"

let b:current_syntax = "modula2"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
