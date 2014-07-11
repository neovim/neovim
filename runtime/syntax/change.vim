" Vim syntax file
" Language:	WEB Changes
" Maintainer:	Andreas Scherer <andreas.scherer@pobox.com>
" Last Change:	April 25, 2001

" Details of the change mechanism of the WEB and CWEB languages can be found
" in the articles by Donald E. Knuth and Silvio Levy cited in "web.vim" and
" "cweb.vim" respectively.

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syn clear
elseif exists("b:current_syntax")
  finish
endif

" We distinguish two groups of material, (a) stuff between @x..@y, and
" (b) stuff between @y..@z. WEB/CWEB ignore everything else in a change file.
syn region changeFromMaterial start="^@x.*$"ms=e+1 end="^@y.*$"me=s-1
syn region changeToMaterial start="^@y.*$"ms=e+1 end="^@z.*$"me=s-1

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_change_syntax_inits")
  if version < 508
    let did_change_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink changeFromMaterial String
  HiLink changeToMaterial Statement

  delcommand HiLink
endif

let b:current_syntax = "change"

" vim: ts=8
