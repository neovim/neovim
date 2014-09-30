" Vim syntax file
" Language:     sinda85, sinda/fluint compare file
" Maintainer:   Adrian Nagle, anagle@ball.com
" Last Change:  2003 May 11
" Filenames:    *.cmp
" URL:		http://www.naglenet.org/vim/syntax/sindacmp.vim
" MAIN URL:     http://www.naglenet.org/vim/



" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_sindacmp_syntax_inits")
  if version < 508
    let did_sindacmp_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink sindacmpTitle		     Type
  HiLink sindacmpUnit		     PreProc

  HiLink sindacmpLabel		     Statement

  HiLink sindacmpHeader		     sindaHeader

  HiLink sindacmpInteger	     Number
  HiLink sindacmpFloat		     Special

  delcommand HiLink
endif


let b:current_syntax = "sindacmp"

" vim: ts=8 sw=2
