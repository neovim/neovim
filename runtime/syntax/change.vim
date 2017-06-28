" Vim syntax file
" Language:	WEB Changes
" Maintainer:	Andreas Scherer <andreas.scherer@pobox.com>
" Last Change:	April 25, 2001

" Details of the change mechanism of the WEB and CWEB languages can be found
" in the articles by Donald E. Knuth and Silvio Levy cited in "web.vim" and
" "cweb.vim" respectively.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" We distinguish two groups of material, (a) stuff between @x..@y, and
" (b) stuff between @y..@z. WEB/CWEB ignore everything else in a change file.
syn region changeFromMaterial start="^@x.*$"ms=e+1 end="^@y.*$"me=s-1
syn region changeToMaterial start="^@y.*$"ms=e+1 end="^@z.*$"me=s-1

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link changeFromMaterial String
hi def link changeToMaterial Statement


let b:current_syntax = "change"

" vim: ts=8
