" Vim indent file
" Language:             Typst
" Maintainer:           Maxim Kim <habamax@gmail.com>
" Previous Maintainer:  Gregory Anders
"                       Luca Saccarola <github.e41mv@aleeas.com>
" Last Change:          2026 Jun 29
" Based on the indent plugin from https://github.com/kaarmu/typst.vim

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal autoindent
setlocal indentexpr=typst#indentexpr()

let b:undo_indent = "setl ai< inde<"
