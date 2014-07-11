" Vim syntax file
" Language:     TAK2, TAK3, TAK2000 thermal modeling compare file
" Maintainer:   Adrian Nagle, anagle@ball.com
" Last Change:  2003 May 11
" Filenames:    *.cmp
" URL:		http://www.naglenet.org/vim/syntax/takcmp.vim
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_takcmp_syntax_inits")
  if version < 508
    let did_takcmp_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink takcmpTitle		   Type
  HiLink takcmpUnit		   PreProc

  HiLink takcmpLabel		   Statement

  HiLink takcmpHeader		   takHeader

  HiLink takcmpDate		   Identifier
  HiLink takcmpTime		   Identifier
  HiLink takcmpInteger		   Number
  HiLink takcmpFloat		   Special

  delcommand HiLink
endif


let b:current_syntax = "takcmp"

" vim: ts=8 sw=2
