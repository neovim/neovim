" Vim syntax file
" Language:	Haskell supporting c2hs binding hooks
" Maintainer:	Armin Sander <armin@mindwalker.org>
" Last Change:	2001 November 1
"
" 2001 November 1: Changed commands for sourcing haskell.vim

" Enable binding hooks
let b:hs_chs=1

" Include standard Haskell highlighting
if version < 600
  source <sfile>:p:h/haskell.vim
else
  runtime! syntax/haskell.vim
endif

" vim: ts=8
