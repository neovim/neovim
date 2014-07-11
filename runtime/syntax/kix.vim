" Vim syntax file
" Language:	KixTart 95, Kix2001 Windows script language http://kixtart.org/
" Maintainer:	Richard Howarth <rhowarth@sgb.co.uk>
" Last Change:	2003 May 11
" URL:		http://www.howsoft.demon.co.uk/

" KixTart files identified by *.kix extension.

" Amendment History:
" 26 April 2001: RMH
"    Removed development comments from distro version
"    Renamed "Kix*" to "kix*" for consistancy
"    Changes made in preperation for VIM version 5.8/6.00

" TODO:
"	Handle arrays highlighting
"	Handle object highlighting
" The next two may not be possible:
"	Work out how to error too many "(", i.e. (() should be an error.
"	Similarly, "if" without "endif" and similar constructs should error.

" Clear legacy syntax rules for version 5.x, exit if already processed for version 6+
if version < 600
	syn clear
elseif exists("b:current_syntax")
	finish
endif

syn case match
syn keyword kixTODO		TODO FIX XXX contained

" Case insensitive language.
syn case ignore

" Kix statements
syn match   kixStatement	"?"
syn keyword kixStatement	beep big break
syn keyword kixStatement	call cd cls color cookie1 copy
syn keyword kixStatement	del dim display
syn keyword kixStatement	exit
syn keyword kixStatement	flushkb
syn keyword kixStatement	get gets global go gosub goto
syn keyword kixStatement	md
syn keyword kixStatement	password play
syn keyword kixStatement	quit
syn keyword kixStatement	rd return run
syn keyword kixStatement	set setl setm settime shell sleep small
syn keyword kixStatement	use

" Kix2001
syn keyword kixStatement	debug function endfunction redim

" Simple variables
syn match   kixNotVar		"\$\$\|@@\|%%" transparent contains=NONE
syn match   kixLocalVar		"\$\w\+"
syn match   kixMacro		"@\w\+"
syn match   kixEnvVar		"%\w\+"

" Destination labels
syn match   kixLabel		":\w\+\>"

" Identify strings, trap unterminated strings
syn match   kixStringError      +".*\|'.*+
syn region  kixDoubleString	oneline start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=kixLocalVar,kixMacro,kixEnvVar,kixNotVar
syn region  kixSingleString	oneline start=+'+ skip=+\\\\\|\\'+ end=+'+ contains=kixLocalVar,kixMacro,kixEnvVar,kixNotVar

" Operators
syn match   kixOperator		"+\|-\|\*\|/\|=\|&\||"
syn keyword kixOperator		and or
" Kix2001
syn match   kixOperator		"=="
syn keyword kixOperator		not

" Numeric constants
syn match   kixInteger		"-\=\<\d\+\>" contains=NONE
syn match   kixFloat		"-\=\.\d\+\>\|-\=\<\d\+\.\d\+\>" contains=NONE

" Hex numeric constants
syn match   kixHex		"\&\x\+\>" contains=NONE

" Other contants
" Kix2001
syn keyword kixConstant		on off

" Comments
syn match   kixComment		";.*$" contains=kixTODO

" Trap unmatched parenthesis
syn match   kixParenCloseError	")"
syn region  kixParen		oneline transparent start="(" end=")" contains=ALLBUT,kixParenCloseError

" Functions (Builtin + UDF)
syn match   kixFunction		"\w\+("he=e-1,me=e-1 contains=ALL

" Trap unmatched brackets
syn match   kixBrackCloseError	"\]"
syn region  kixBrack		transparent start="\[" end="\]" contains=ALLBUT,kixBrackCloseError

" Clusters for ALLBUT shorthand
syn cluster kixIfBut		contains=kixIfError,kixSelectOK,kixDoOK,kixWhileOK,kixForEachOK,kixForNextOK
syn cluster kixSelectBut	contains=kixSelectError,kixIfOK,kixDoOK,kixWhileOK,kixForEachOK,kixForNextOK
syn cluster kixDoBut		contains=kixDoError,kixSelectOK,kixIfOK,kixWhileOK,kixForEachOK,kixForNextOK
syn cluster kixWhileBut		contains=kixWhileError,kixSelectOK,kixIfOK,kixDoOK,kixForEachOK,kixForNextOK
syn cluster kixForEachBut	contains=kixForEachError,kixSelectOK,kixIfOK,kixDoOK,kixForNextOK,kixWhileOK
syn cluster kixForNextBut	contains=kixForNextError,kixSelectOK,kixIfOK,kixDoOK,kixForEachOK,kixWhileOK
" Condtional construct errors.
syn match   kixIfError		"\<if\>\|\<else\>\|\<endif\>"
syn match   kixIfOK		contained "\<if\>\|\<else\>\|\<endif\>"
syn region  kixIf		transparent matchgroup=kixIfOK start="\<if\>" end="\<endif\>" contains=ALLBUT,@kixIfBut
syn match   kixSelectError	"\<select\>\|\<case\>\|\<endselect\>"
syn match   kixSelectOK		contained "\<select\>\|\<case\>\|\<endselect\>"
syn region  kixSelect		transparent matchgroup=kixSelectOK start="\<select\>" end="\<endselect\>" contains=ALLBUT,@kixSelectBut

" Program control constructs.
syn match   kixDoError		"\<do\>\|\<until\>"
syn match   kixDoOK		contained "\<do\>\|\<until\>"
syn region  kixDo		transparent matchgroup=kixDoOK start="\<do\>" end="\<until\>" contains=ALLBUT,@kixDoBut
syn match   kixWhileError	"\<while\>\|\<loop\>"
syn match   kixWhileOK		contained "\<while\>\|\<loop\>"
syn region  kixWhile		transparent matchgroup=kixWhileOK start="\<while\>" end="\<loop\>" contains=ALLBUT,@kixWhileBut
syn match   kixForNextError	"\<for\>\|\<to\>\|\<step\>\|\<next\>"
syn match   kixForNextOK	contained "\<for\>\|\<to\>\|\<step\>\|\<next\>"
syn region  kixForNext		transparent matchgroup=kixForNextOK start="\<for\>" end="\<next\>" contains=ALLBUT,@kixForBut
syn match   kixForEachError	"\<for each\>\|\<in\>\|\<next\>"
syn match   kixForEachOK	contained "\<for each\>\|\<in\>\|\<next\>"
syn region  kixForEach		transparent matchgroup=kixForEachOK start="\<for each\>" end="\<next\>" contains=ALLBUT,@kixForEachBut

" Expressions
syn match   kixExpression	"<\|>\|<=\|>=\|<>"


" Default highlighting.
" Version < 5.8 set default highlight if file not already processed.
" Version >= 5.8 set default highlight only if it doesn't already have a value.
if version > 508 || !exists("did_kix_syn_inits")
	if version < 508
		let did_kix_syn_inits=1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
	endif

	HiLink kixDoubleString		String
	HiLink kixSingleString		String
	HiLink kixStatement		Statement
	HiLink kixRepeat		Repeat
	HiLink kixComment		Comment
	HiLink kixBuiltin		Function
	HiLink kixLocalVar		Special
	HiLink kixMacro			Special
	HiLink kixEnvVar		Special
	HiLink kixLabel			Type
	HiLink kixFunction		Function
	HiLink kixInteger		Number
	HiLink kixHex			Number
	HiLink kixFloat			Number
	HiLink kixOperator		Operator
	HiLink kixExpression		Operator

	HiLink kixParenCloseError	Error
	HiLink kixBrackCloseError	Error
	HiLink kixStringError		Error

	HiLink kixWhileError		Error
	HiLink kixWhileOK		Conditional
	HiLink kixDoError		Error
	HiLink kixDoOK			Conditional
	HiLink kixIfError		Error
	HiLink kixIfOK			Conditional
	HiLink kixSelectError		Error
	HiLink kixSelectOK		Conditional
	HiLink kixForNextError		Error
	HiLink kixForNextOK		Conditional
	HiLink kixForEachError		Error
	HiLink kixForEachOK		Conditional

	delcommand HiLink
endif

let b:current_syntax = "kix"

" vim: ts=8 sw=2
