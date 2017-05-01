" Vim syntax file
" Language:	Matlab
" Maintainer:	Alex Burka <vim@alexburka.com>
" Credits:	Preben 'Peppe' Guldberg <peppe-vim@wielders.org>
"		Maurizio Tranchero - maurizio(.)tranchero(@)gmail(.)com
"		Original author: Mario Eusebio
" Last Change:	Mon Jan 23 2017
" 		added support for cell mode
" Change History:
" 		- now highlights cell-mode separator comments
" 		- 'global' and 'persistent' keyword are now recognized

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn keyword matlabStatement		return
syn keyword matlabLabel			case switch
syn keyword matlabConditional		else elseif end if otherwise
syn keyword matlabRepeat		do for while
" MT_ADDON - added exception-specific keywords
syn keyword matlabExceptions		try catch
syn keyword matlabOO			classdef properties events methods

syn keyword matlabTodo			contained  TODO
syn keyword matlabScope			global persistent

" If you do not want these operators lit, uncommment them and the "hi link" below
syn match matlabArithmeticOperator	"[-+]"
syn match matlabArithmeticOperator	"\.\=[*/\\^]"
syn match matlabRelationalOperator	"[=~]="
syn match matlabRelationalOperator	"[<>]=\="
syn match matlabLogicalOperator		"[&|~]"

syn match matlabLineContinuation	"\.\{3}"

"syn match matlabIdentifier		"\<\a\w*\>"

" String
" MT_ADDON - added 'skip' in order to deal with 'tic' escaping sequence 
syn region matlabString			start=+'+ end=+'+	oneline skip=+''+

" If you don't like tabs
syn match matlabTab			"\t"

" Standard numbers
syn match matlabNumber		"\<\d\+[ij]\=\>"
" floating point number, with dot, optional exponent
syn match matlabFloat		"\<\d\+\(\.\d*\)\=\([edED][-+]\=\d\+\)\=[ij]\=\>"
" floating point number, starting with a dot, optional exponent
syn match matlabFloat		"\.\d\+\([edED][-+]\=\d\+\)\=[ij]\=\>"

" Transpose character and delimiters: Either use just [...] or (...) aswell
syn match matlabDelimiter		"[][]"
"syn match matlabDelimiter		"[][()]"
syn match matlabTransposeOperator	"[])a-zA-Z0-9.]'"lc=1

syn match matlabSemicolon		";"

syn match matlabComment			"%.*$"	contains=matlabTodo,matlabTab
" MT_ADDON - correctly highlights words after '...' as comments
syn match matlabComment			"\.\.\..*$"	contains=matlabTodo,matlabTab
syn region matlabMultilineComment	start=+%{+ end=+%}+ contains=matlabTodo,matlabTab
syn match matlabCellComment     "^%%.*$"

syn keyword matlabOperator		break zeros default margin round ones rand
syn keyword matlabOperator		ceil floor size clear zeros eye mean std cov

syn keyword matlabFunction		error eval function

syn keyword matlabImplicit		abs acos atan asin cos cosh exp log prod sum
syn keyword matlabImplicit		log10 max min sign sin sinh sqrt tan reshape

syn match matlabError	"-\=\<\d\+\.\d\+\.[^*/\\^]"
syn match matlabError	"-\=\<\d\+\.\d\+[eEdD][-+]\=\d\+\.\([^*/\\^]\)"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link matlabTransposeOperator	matlabOperator
hi def link matlabOperator			Operator
hi def link matlabLineContinuation		Special
hi def link matlabLabel			Label
hi def link matlabConditional		Conditional
hi def link matlabExceptions		Conditional
hi def link matlabRepeat			Repeat
hi def link matlabTodo			Todo
hi def link matlabString			String
hi def link matlabDelimiter		Identifier
hi def link matlabTransposeOther		Identifier
hi def link matlabNumber			Number
hi def link matlabFloat			Float
hi def link matlabFunction			Function
hi def link matlabError			Error
hi def link matlabImplicit			matlabStatement
hi def link matlabStatement		Statement
hi def link matlabOO			Statement
hi def link matlabSemicolon		SpecialChar
hi def link matlabComment			Comment
hi def link matlabMultilineComment		Comment
hi def link matlabCellComment          Todo
hi def link matlabScope			Type

hi def link matlabArithmeticOperator	matlabOperator
hi def link matlabRelationalOperator	matlabOperator
hi def link matlabLogicalOperator		matlabOperator

"optional highlighting
"hi def link matlabIdentifier		Identifier
"hi def link matlabTab			Error


let b:current_syntax = "matlab"

"EOF	vim: ts=8 noet tw=100 sw=8 sts=0
