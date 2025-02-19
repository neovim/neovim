" Vim syntax file
" Language:	Boundary Scan Description Language (BSDL)
" Maintainer:	Daniel Kho <daniel.kho@logik.haus>
" Last Changed:	2020 Mar 19 by Daniel Kho

" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

" Read in VHDL syntax files
runtime! syntax/vhdl.vim
unlet b:current_syntax

let b:current_syntax = "bsdl"

" vim: ts=8
