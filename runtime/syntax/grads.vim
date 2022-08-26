" Vim syntax file
" Language:	grads (GrADS scripts)
" Maintainer:	Stefan Fronzek (sfronzek at gmx dot net)
" Last change: 13 Feb 2004

" Grid Analysis and Display System (GrADS); http://grads.iges.org/grads
" This syntax file defines highlighting for only very few features of
" the GrADS scripting language.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" GrADS is entirely case-insensitive.
syn case ignore

" The keywords

syn keyword gradsStatement	if else endif break exit return
syn keyword gradsStatement	while endwhile say prompt pull function
syn keyword gradsStatement subwrd sublin substr read write close
" String

syn region gradsString		start=+'+ end=+'+

" Integer number
syn match  gradsNumber		"[+-]\=\<[0-9]\+\>"

" Operator

"syn keyword gradsOperator	| ! % & != >=
"syn match gradsOperator		"[^\.]not[^a-zA-Z]"

" Variables

syn keyword gradsFixVariables	lat lon lev result rec rc
syn match gradsglobalVariables	"_[a-zA-Z][a-zA-Z0-9]*"
syn match gradsVariables		"[a-zA-Z][a-zA-Z0-9]*"
syn match gradsConst		"#[A-Z][A-Z_]+"

" Comments

syn match gradsComment	"\*.*"

" Typical Typos

" for C programmers:
" syn match gradsTypos	"=="
" syn match gradsTypos	"!="

" Define the default highlighting.
" Only when an item doesn't hgs highlighting+yet

hi def link gradsStatement		Statement

hi def link gradsString		String
hi def link gradsNumber		Number

hi def link gradsFixVariables	Special
hi def link gradsVariables		Identifier
hi def link gradsglobalVariables	Special
hi def link gradsConst		Special

hi def link gradsClassMethods	Function

hi def link gradsOperator		Operator
hi def link gradsComment		Comment

hi def link gradsTypos		Error


let b:current_syntax = "grads"
