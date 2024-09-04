" Vim indent file
" Language:    HCL
" Maintainer:  Gregory Anders
" Upstream:    https://github.com/hashivim/vim-terraform
" Last Change: 2024-09-03

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

setlocal autoindent shiftwidth=2 tabstop=2 softtabstop=2 expandtab
setlocal indentexpr=hcl#indentexpr(v:lnum)
setlocal indentkeys+=<:>,0=},0=)

let b:undo_indent = 'setlocal ai< sw< ts< sts< et< inde< indk<'
