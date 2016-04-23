" Vim indent file
" Language:	Javascript
" Maintainer:	Going to be Darrick Wiebe
" Last Change:	2015 Jun 09

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif
let b:did_indent = 1

" C indenting is not too bad.
setlocal cindent
setlocal cinoptions+=j1,J1
setlocal cinkeys-=0#
setlocal cinkeys+=0]

let b:undo_indent = "setl cin<"
