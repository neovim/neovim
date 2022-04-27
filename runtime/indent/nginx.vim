" Vim indent file
" Language: nginx.conf
" Maintainer: Chris Aumann <me@chr4.org>
" Last Change:  2022 Apr 06

if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal indentexpr=

" cindent actually works for nginx' simple file structure
setlocal cindent

" Just make sure that the comments are not reset as defs would be.
setlocal cinkeys-=0#

let b:undo_indent = "setl inde< cin< cink<"
