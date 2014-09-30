"
" Vim syntax file
" Language   :	Scilab
" Maintainer :	Benoit Hamelin
" File type  :	*.sci (see :help filetype)
" History
"	28jan2002	benoith		0.1		Creation.  Adapted from matlab.vim.
"	04feb2002	benoith		0.5		Fixed bugs with constant highlighting.
"


" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif


" Reserved words.
syn keyword scilabStatement			abort clear clearglobal end exit global mode predef quit resume
syn keyword scilabStatement			return
syn keyword scilabFunction			function endfunction funptr
syn keyword scilabPredicate			null iserror isglobal
syn keyword scilabKeyword			typename
syn keyword scilabDebug				debug pause what where whereami whereis who whos
syn keyword scilabRepeat			for while break
syn keyword scilabConditional		if then else elseif
syn keyword scilabMultiplex			select case

" Reserved constants.
syn match scilabConstant			"\(%\)[0-9A-Za-z?!#$]\+"
syn match scilabBoolean				"\(%\)[FTft]\>"

" Delimiters and operators.
syn match scilabDelimiter			"[][;,()]"
syn match scilabComparison			"[=~]="
syn match scilabComparison			"[<>]=\="
syn match scilabComparison			"<>"
syn match scilabLogical				"[&|~]"
syn match scilabAssignment			"="
syn match scilabArithmetic			"[+-]"
syn match scilabArithmetic			"\.\=[*/\\]\.\="
syn match scilabArithmetic			"\.\=^"
syn match scilabRange				":"
syn match scilabMlistAccess			"\."

syn match scilabLineContinuation	"\.\{2,}"

syn match scilabTransposition		"[])a-zA-Z0-9?!_#$.]'"lc=1

" Comments and tools.
syn keyword scilabTodo				TODO todo FIXME fixme TBD tbd	contained
syn match scilabComment				"//.*$"	contains=scilabTodo

" Constants.
syn match scilabNumber				"[0-9]\+\(\.[0-9]*\)\=\([DEde][+-]\=[0-9]\+\)\="
syn match scilabNumber				"\.[0-9]\+\([DEde][+-]\=[0-9]\+\)\="
syn region scilabString				start=+'+ skip=+''+ end=+'+		oneline
syn region scilabString				start=+"+ end=+"+				oneline

" Identifiers.
syn match scilabIdentifier			"\<[A-Za-z?!_#$][A-Za-z0-9?!_#$]*\>"
syn match scilabOverload			"%[A-Za-z0-9?!_#$]\+_[A-Za-z0-9?!_#$]\+"


" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_scilab_syntax_inits")
	if version < 508
		let did_scilab_syntax_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
	endif

	HiLink	scilabStatement				Statement
	HiLink	scilabFunction				Keyword
	HiLink	scilabPredicate				Keyword
	HiLink	scilabKeyword				Keyword
	HiLink	scilabDebug					Debug
	HiLink	scilabRepeat				Repeat
	HiLink	scilabConditional			Conditional
	HiLink	scilabMultiplex				Conditional

	HiLink	scilabConstant				Constant
	HiLink	scilabBoolean				Boolean

	HiLink	scilabDelimiter				Delimiter
	HiLink	scilabMlistAccess			Delimiter
	HiLink	scilabComparison			Operator
	HiLink	scilabLogical				Operator
	HiLink	scilabAssignment			Operator
	HiLink	scilabArithmetic			Operator
	HiLink	scilabRange					Operator
	HiLink	scilabLineContinuation		Underlined
	HiLink	scilabTransposition			Operator

	HiLink	scilabTodo					Todo
	HiLink	scilabComment				Comment

	HiLink	scilabNumber				Number
	HiLink	scilabString				String

	HiLink	scilabIdentifier			Identifier
	HiLink	scilabOverload				Special

	delcommand HiLink
endif

let b:current_syntax = "scilab"

"EOF	vim: ts=4 noet tw=100 sw=4 sts=0
