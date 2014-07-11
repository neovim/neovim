" Vim syntax file
" Language:	Matlab
" Maintainer:	Maurizio Tranchero - maurizio(.)tranchero(@)gmail(.)com
" Credits:	Preben 'Peppe' Guldberg <peppe-vim@wielders.org>
"		Original author: Mario Eusebio
" Last Change:	Wed Jan 13 11:12:34 CET 2010
" 		sinh added to matlab implicit commands
" Change History:
" 		- 'global' and 'persistent' keyword are now recognized

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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

syn keyword matlabOperator		break zeros default margin round ones rand
syn keyword matlabOperator		ceil floor size clear zeros eye mean std cov

syn keyword matlabFunction		error eval function

syn keyword matlabImplicit		abs acos atan asin cos cosh exp log prod sum
syn keyword matlabImplicit		log10 max min sign sin sinh sqrt tan reshape

syn match matlabError	"-\=\<\d\+\.\d\+\.[^*/\\^]"
syn match matlabError	"-\=\<\d\+\.\d\+[eEdD][-+]\=\d\+\.\([^*/\\^]\)"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_matlab_syntax_inits")
  if version < 508
    let did_matlab_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink matlabTransposeOperator	matlabOperator
  HiLink matlabOperator			Operator
  HiLink matlabLineContinuation		Special
  HiLink matlabLabel			Label
  HiLink matlabConditional		Conditional
  HiLink matlabExceptions		Conditional
  HiLink matlabRepeat			Repeat
  HiLink matlabTodo			Todo
  HiLink matlabString			String
  HiLink matlabDelimiter		Identifier
  HiLink matlabTransposeOther		Identifier
  HiLink matlabNumber			Number
  HiLink matlabFloat			Float
  HiLink matlabFunction			Function
  HiLink matlabError			Error
  HiLink matlabImplicit			matlabStatement
  HiLink matlabStatement		Statement
  HiLink matlabOO			Statement
  HiLink matlabSemicolon		SpecialChar
  HiLink matlabComment			Comment
  HiLink matlabMultilineComment		Comment
  HiLink matlabScope			Type

  HiLink matlabArithmeticOperator	matlabOperator
  HiLink matlabRelationalOperator	matlabOperator
  HiLink matlabLogicalOperator		matlabOperator

"optional highlighting
  "HiLink matlabIdentifier		Identifier
  "HiLink matlabTab			Error

  delcommand HiLink
endif

let b:current_syntax = "matlab"

"EOF	vim: ts=8 noet tw=100 sw=8 sts=0
