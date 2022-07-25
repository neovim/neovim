" Vim indent file
" Language:             BitBake
" Copyright:            Copyright (C) 2019 Agilent Technologies, Inc.
" Maintainer:           Chris Laplante <chris.laplante@agilent.com>
" License:              You may redistribute this under the same terms as Vim itself

if exists("b:did_indent")
    finish
endif

runtime! indent/sh.vim

setlocal indentexpr=bitbake#Indent(v:lnum)
setlocal autoindent
setlocal nolisp
setlocal shiftwidth=4
setlocal expandtab
setlocal indentkeys+=<:>,=elif,=except,0=\"

let b:undo_indent .= ' inde< ai< lisp< sw< et< indk<'

let b:did_indent = 1
