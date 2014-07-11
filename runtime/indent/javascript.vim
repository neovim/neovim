" Vim indent file
" Language:	Javascript
" Maintainer:	None!  Wanna improve this?
" Last Change:	2007 Jan 22

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif
let b:did_indent = 1

" C indenting is not too bad.
setlocal cindent
setlocal cinoptions+=j1,J1

let b:undo_indent = "setl cin<"
