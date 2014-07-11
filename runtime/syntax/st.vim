" Vim syntax file
" Language:	Smalltalk
" Maintainer:	Arndt Hesse <hesse@self.de>
" Last Change:	2012 Feb 12 by Thilo Six

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_st_syntax_inits")
  if version < 508
    let did_st_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink stKeyword		Statement
  HiLink stMethod		Statement
  HiLink stComment		Comment
  HiLink stCharacter		Constant
  HiLink stString		Constant
  HiLink stSymbol		Special
  HiLink stNumber		Type
  HiLink stFloat		Type
  HiLink stError		Error
  HiLink stLocalVariables	Identifier
  HiLink stBlockVariable	Identifier

  delcommand HiLink
endif

let b:current_syntax = "st"

let &cpo = s:cpo_save
unlet s:cpo_save
