" Vim indent file
" Language: D script as described in "Solaris Dynamic Tracing Guide",
"           http://docs.sun.com/app/docs/doc/817-6223
" Last Change: 2008/03/20
" Version: 1.2
" Maintainer: Nicolas Weber <nicolasweber@gmx.de>

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif
let b:did_indent = 1

" Built-in C indenting works nicely for dtrace.
setlocal cindent

let b:undo_indent = "setl cin<"
