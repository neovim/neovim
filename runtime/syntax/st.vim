" Vim syntax file
" Language:	Smalltalk
" Maintainer:	Arndt Hesse <hesse@self.de>
" Last Change:	2012 Feb 12 by Thilo Six

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" some Smalltalk keywords and standard methods
syn keyword	stKeyword	super self class true false new not
syn keyword	stKeyword	notNil isNil inspect out nil
syn match	stMethod	"\<do\>:"
syn match	stMethod	"\<whileTrue\>:"
syn match	stMethod	"\<whileFalse\>:"
syn match	stMethod	"\<ifTrue\>:"
syn match	stMethod	"\<ifFalse\>:"
syn match	stMethod	"\<put\>:"
syn match	stMethod	"\<to\>:"
syn match	stMethod	"\<at\>:"
syn match	stMethod	"\<add\>:"
syn match	stMethod	"\<new\>:"
syn match	stMethod	"\<for\>:"
syn match	stMethod	"\<methods\>:"
syn match	stMethod	"\<methodsFor\>:"
syn match	stMethod	"\<instanceVariableNames\>:"
syn match	stMethod	"\<classVariableNames\>:"
syn match	stMethod	"\<poolDictionaries\>:"
syn match	stMethod	"\<subclass\>:"

" the block of local variables of a method
syn region stLocalVariables	start="^[ \t]*|" end="|"

" the Smalltalk comment
syn region stComment	start="\"" end="\""

" the Smalltalk strings and single characters
syn region stString	start='\'' skip="''" end='\''
syn match  stCharacter	"$."

syn case ignore

" the symols prefixed by a '#'
syn match  stSymbol	"\(#\<[a-z_][a-z0-9_]*\>\)"
syn match  stSymbol	"\(#'[^']*'\)"

" the variables in a statement block for loops
syn match  stBlockVariable "\(:[ \t]*\<[a-z_][a-z0-9_]*\>[ \t]*\)\+|" contained

" some representations of numbers
syn match  stNumber	"\<\d\+\(u\=l\=\|lu\|f\)\>"
syn match  stFloat	"\<\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\=\>"
syn match  stFloat	"\<\d\+e[-+]\=\d\+[fl]\=\>"

syn case match

" a try to higlight paren mismatches
syn region stParen	transparent start='(' end=')' contains=ALLBUT,stParenError
syn match  stParenError	")"
syn region stBlock	transparent start='\[' end='\]' contains=ALLBUT,stBlockError
syn match  stBlockError	"\]"
syn region stSet	transparent start='{' end='}' contains=ALLBUT,stSetError
syn match  stSetError	"}"

hi link stParenError stError
hi link stSetError stError
hi link stBlockError stError

" synchronization for syntax analysis
syn sync minlines=50

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link stKeyword		Statement
hi def link stMethod		Statement
hi def link stComment		Comment
hi def link stCharacter		Constant
hi def link stString		Constant
hi def link stSymbol		Special
hi def link stNumber		Type
hi def link stFloat		Type
hi def link stError		Error
hi def link stLocalVariables	Identifier
hi def link stBlockVariable	Identifier


let b:current_syntax = "st"

let &cpo = s:cpo_save
unlet s:cpo_save
