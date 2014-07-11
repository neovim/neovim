" Vim syntax file
" Copyright by Jan-Oliver Wagner
" Language:	avenue
" Maintainer:	Jan-Oliver Wagner <Jan-Oliver.Wagner@intevation.de>
" Last change:	2001 May 10

" Avenue is the ArcView built-in language. ArcView is
" a desktop GIS by ESRI. Though it is a built-in language
" and a built-in editor is provided, the use of VIM increases
" development speed.
" I use some technologies to automatically load avenue scripts
" into ArcView.

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Avenue is entirely case-insensitive.
syn case ignore

" The keywords

syn keyword aveStatement	if then elseif else end break exit return
syn keyword aveStatement	for each in continue while

" String

syn region aveString		start=+"+ end=+"+

" Integer number
syn match  aveNumber		"[+-]\=\<[0-9]\+\>"

" Operator

syn keyword aveOperator		or and max min xor mod by
" 'not' is a kind of a problem: Its an Operator as well as a method
" 'not' is only marked as an Operator if not applied as method
syn match aveOperator		"[^\.]not[^a-zA-Z]"

" Variables

syn keyword aveFixVariables	av nil self false true nl tab cr tab
syn match globalVariables	"_[a-zA-Z][a-zA-Z0-9]*"
syn match aveVariables		"[a-zA-Z][a-zA-Z0-9_]*"
syn match aveConst		"#[A-Z][A-Z_]+"

" Comments

syn match aveComment	"'.*"

" Typical Typos

" for C programmers:
syn match aveTypos	"=="
syn match aveTypos	"!="

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting+yet
if version >= 508 || !exists("did_ave_syn_inits")
  if version < 508
	let did_ave_syn_inits = 1
	command -nargs=+ HiLink hi link <args>
  else
	command -nargs=+ HiLink hi def link <args>
  endif

  HiLink aveStatement		Statement

  HiLink aveString		String
  HiLink aveNumber		Number

  HiLink aveFixVariables	Special
  HiLink aveVariables		Identifier
  HiLink globalVariables	Special
  HiLink aveConst		Special

  HiLink aveClassMethods	Function

  HiLink aveOperator		Operator
  HiLink aveComment		Comment

  HiLink aveTypos		Error

  delcommand HiLink
endif

let b:current_syntax = "ave"
