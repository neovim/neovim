" Vim indent file
" Language: nginx.conf
" Maintainer: Chris Aumann <me@chr4.org>
" Last Change: Apr 15, 2017

if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal indentexpr=

" cindent actually works for nginx' simple file structure
setlocal cindent

" Just make sure that the comments are not reset as defs would be.
setlocal cinkeys-=0#
