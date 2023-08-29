" Vim indent file
" Language: dune
" Maintainers:  Markus Mottl         <markus.mottl@gmail.com>
" URL:          https://github.com/ocaml/vim-ocaml
" Last Change:  2021 Jan 01
"               2023 Aug 28 by Vim Project (undo_indent)

if exists("b:did_indent")
 finish
endif
let b:did_indent = 1

" dune format-dune-file uses 1 space to indent
setlocal softtabstop=1 shiftwidth=1 expandtab

let b:undo_indent = "setl et< sts< sw<"
