" Vim indent file
" Language:	Mail
" Maintainer:	Bram Moolenaar
" Last Change:	2021 Sep 26

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

" What works best is auto-indenting, disable other indenting.
" For formatting see the ftplugin.
setlocal autoindent nosmartindent nocindent indentexpr=

let b:undo_indent = "setl ai< cin< inde< si<"
