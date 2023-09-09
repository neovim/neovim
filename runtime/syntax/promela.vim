" Vim syntax file
" Language:			ProMeLa
" Maintainer:		Maurizio Tranchero <maurizio.tranchero@polito.it> - <maurizio.tranchero@gmail.com>
" First Release:	Mon Oct 16 08:49:46 CEST 2006
" Last Change:		Thu Aug 7 21:22:48 CEST 2008
" Version:			0.5

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" case is significant
" syn case ignore
" ProMeLa Keywords
syn keyword promelaStatement	proctype if else while chan do od fi break goto unless
syn keyword promelaStatement	active assert label atomic
syn keyword promelaFunctions	skip timeout run
syn keyword promelaTodo         contained TODO
" ProMeLa Types
syn keyword promelaType			bit bool byte short int
" Operators and special characters
syn match promelaOperator	"!"
syn match promelaOperator	"?"
syn match promelaOperator	"->"
syn match promelaOperator	"="
syn match promelaOperator	"+"
syn match promelaOperator	"*"
syn match promelaOperator	"/"
syn match promelaOperator	"-"
syn match promelaOperator	"<"
syn match promelaOperator	">"
syn match promelaOperator	"<="
syn match promelaOperator	">="
syn match promelaSpecial	"\["
syn match promelaSpecial	"\]"
syn match promelaSpecial	";"
syn match promelaSpecial	"::"
" ProMeLa Comments
syn region promelaComment start="/\*" end="\*/" contains=promelaTodo,@Spell
syn match  promelaComment "//.*" contains=promelaTodo,@Spell

" Class Linking
hi def link promelaStatement    Statement
hi def link promelaType	        Type
hi def link promelaComment      Comment
hi def link promelaOperator	    Type
hi def link promelaSpecial      Special
hi def link promelaFunctions    Special
hi def link promelaString		String
hi def link promelaTodo	        Todo

let b:current_syntax = "promela"
