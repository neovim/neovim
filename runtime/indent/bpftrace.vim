" Vim indent file
" Language:     bpftrace
" Author:       Stanislaw Gruszka <stf_xl@wp.pl>
" Last Change:  2025 Dec 27

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal noautoindent nosmartindent

setlocal cindent
setlocal cinoptions=+0,(0,[0,Ws,J1,j1,m1,>s
setlocal cinkeys=0{,0},!^F,o,O,#0
setlocal cinwords=

let b:undo_indent = "setlocal autoindent< smartindent< cindent< cinoptions< cinkeys< cinwords<"
