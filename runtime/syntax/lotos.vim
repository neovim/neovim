" Vim syntax file
" Language:	LOTOS (Language Of Temporal Ordering Specifications, IS8807)
" Maintainer:	Daniel Amyot <damyot@csi.uottawa.ca>
" Last Change:	Wed Aug 19 1998
" URL:		http://lotos.csi.uottawa.ca/~damyot/vim/lotos.vim
" This file is an adaptation of pascal.vim by Mario Eusebio
" I'm not sure I understand all of the syntax highlight language,
" but this file seems to do the job for standard LOTOS.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

"Comments in LOTOS are between (* and *)
syn region lotosComment	start="(\*"  end="\*)" contains=lotosTodo

"Operators [], [...], >>, ->, |||, |[...]|, ||, ;, !, ?, :, =, ,, :=
syn match  lotosDelimiter       "[][]"
syn match  lotosDelimiter	">>"
syn match  lotosDelimiter	"->"
syn match  lotosDelimiter	"\[>"
syn match  lotosDelimiter	"[|;!?:=,]"

"Regular keywords
syn keyword lotosStatement	specification endspec process endproc
syn keyword lotosStatement	where behaviour behavior
syn keyword lotosStatement      any let par accept choice hide of in
syn keyword lotosStatement	i stop exit noexit

"Operators from the Abstract Data Types in IS8807
syn keyword lotosOperator	eq ne succ and or xor implies iff
syn keyword lotosOperator	not true false
syn keyword lotosOperator	Insert Remove IsIn NotIn Union Ints
syn keyword lotosOperator	Minus Includes IsSubsetOf
syn keyword lotosOperator	lt le ge gt 0

"Sorts in IS8807
syn keyword lotosSort		Boolean Bool FBoolean FBool Element
syn keyword lotosSort		Set String NaturalNumber Nat HexString
syn keyword lotosSort		HexDigit DecString DecDigit
syn keyword lotosSort		OctString OctDigit BitString Bit
syn keyword lotosSort		Octet OctetString

"Keywords for ADTs
syn keyword lotosType	type endtype library endlib sorts formalsorts
syn keyword lotosType	eqns formaleqns opns formalopns forall ofsort is
syn keyword lotosType   for renamedby actualizedby sortnames opnnames
syn keyword lotosType   using

syn sync lines=250

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link lotosStatement		Statement
hi def link lotosProcess		Label
hi def link lotosOperator		Operator
hi def link lotosSort		Function
hi def link lotosType		Type
hi def link lotosComment		Comment
hi def link lotosDelimiter		String


let b:current_syntax = "lotos"

" vim: ts=8
