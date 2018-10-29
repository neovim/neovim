" Vim indent file
" Language:     WebAssembly
" Maintainer:   rhysd <lin90162@yahoo.co.jp>
" Last Change:  Jul 29, 2018
" For bugs, patches and license go to https://github.com/rhysd/vim-wasm

if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

" WebAssembly text format is S-expression. We can reuse LISP indentation
" logic.
setlocal indentexpr=lispindent('.')
setlocal noautoindent nosmartindent

let b:undo_indent = "setl lisp< indentexpr<"
