" Vim syntax file
" Language:     sinda85, sinda/fluint compare file
" Maintainer:   Adrian Nagle, anagle@ball.com
" Last Change:  2003 May 11
" Filenames:    *.cmp
" URL:		http://www.naglenet.org/vim/syntax/sindacmp.vim
" MAIN URL:     http://www.naglenet.org/vim/



" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif



" Ignore case
syn case ignore



"
" Begin syntax definitions for compare files.
"

" Define keywords for sinda compare (sincomp)
syn keyword sindacmpUnit     celsius fahrenheit



" Define matches for sinda compare (sincomp)
syn match  sindacmpTitle       "Steady State Temperature Comparison"

syn match  sindacmpLabel       "File  [1-6] is"

syn match  sindacmpHeader      "^ *Node\( *File  \d\)* *Node Description"

syn match  sindacmpInteger     "^ *-\=\<[0-9]*\>"
syn match  sindacmpFloat       "-\=\<[0-9]*\.[0-9]*"



" Define the default highlighting
" Only when an item doesn't have highlighting yet

hi def link sindacmpTitle		     Type
hi def link sindacmpUnit		     PreProc

hi def link sindacmpLabel		     Statement

hi def link sindacmpHeader		     sindaHeader

hi def link sindacmpInteger	     Number
hi def link sindacmpFloat		     Special



let b:current_syntax = "sindacmp"

" vim: ts=8 sw=2
