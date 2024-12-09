" Vim indent file
" Language:    Typst
" Previous Maintainer:  Gregory Anders
" Maintainer:  Luca Saccarola <github.e41mv@aleeas.com>
" Last Change: 2024 Dec 09
" Based on:    https://github.com/kaarmu/typst.vim

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

setlocal expandtab
setlocal softtabstop=2
setlocal shiftwidth=2
setlocal autoindent
setlocal indentexpr=typst#indentexpr()

let b:undo_indent = 'setl et< sts< sw< ai< inde<'
