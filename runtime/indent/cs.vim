" Vim indent file
" Language:	C#
" Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:	Fri, 15 Mar 2002 07:53:54 CET

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif
let b:did_indent = 1

" C# is like indenting C
setlocal cindent

let b:undo_indent = "setl cin<"
