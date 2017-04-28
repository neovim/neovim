" Vim syntax file
" Language:     TAK2, TAK3, TAK2000 thermal modeling compare file
" Maintainer:   Adrian Nagle, anagle@ball.com
" Last Change:  2003 May 11
" Filenames:    *.cmp
" URL:		http://www.naglenet.org/vim/syntax/takcmp.vim
" MAIN URL:     http://www.naglenet.org/vim/



" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif



" Ignore case
syn case ignore



"
"
" Begin syntax definitions for compare files.
"
" Define keywords for TAK compare
  syn keyword takcmpUnit     celsius fahrenheit



" Define matches for TAK compare
  syn match  takcmpTitle       "Steady State Temperature Comparison"

  syn match  takcmpLabel       "Run Date:"
  syn match  takcmpLabel       "Run Time:"
  syn match  takcmpLabel       "Temp. File \d Units:"
  syn match  takcmpLabel       "Filename:"
  syn match  takcmpLabel       "Output Units:"

  syn match  takcmpHeader      "^ *Node\( *File  \d\)* *Node Description"

  syn match  takcmpDate        "\d\d\/\d\d\/\d\d"
  syn match  takcmpTime        "\d\d:\d\d:\d\d"
  syn match  takcmpInteger     "^ *-\=\<[0-9]*\>"
  syn match  takcmpFloat       "-\=\<[0-9]*\.[0-9]*"



" Define the default highlighting
" Only when an item doesn't have highlighting yet

hi def link takcmpTitle		   Type
hi def link takcmpUnit		   PreProc

hi def link takcmpLabel		   Statement

hi def link takcmpHeader		   takHeader

hi def link takcmpDate		   Identifier
hi def link takcmpTime		   Identifier
hi def link takcmpInteger		   Number
hi def link takcmpFloat		   Special



let b:current_syntax = "takcmp"

" vim: ts=8 sw=2
