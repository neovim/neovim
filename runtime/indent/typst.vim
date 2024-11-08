" Vim indent file
" Language:    Typst
" Maintainer:  Gregory Anders <greg@gpanders.com>
" Last Change: 2024-07-14
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
