" Vim indent file
" Language:      BibTeX
" Maintainer:    Dorai Sitaram <ds26@gte.com>
" URL:		 http://www.ccs.neu.edu/~dorai/vimplugins/vimplugins.html
" Last Change:   2005 Mar 28

" Only do this when not done yet for this buffer
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal cindent

let b:undo_indent = "setl cin<"
