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
"    Changes made in preparation for VIM version 5.8/6.00

" TODO:
"	Handle arrays highlighting
"	Handle object highlighting
" The next two may not be possible:
"	Work out how to error too many "(", i.e. (() should be an error.
"	Similarly, "if" without "endif" and similar constructs should error.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
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
" Set default highlight only if it doesn't already have a value.

hi def link kixDoubleString		String
hi def link kixSingleString		String
hi def link kixStatement		Statement
hi def link kixRepeat		Repeat
hi def link kixComment		Comment
hi def link kixBuiltin		Function
hi def link kixLocalVar		Special
hi def link kixMacro			Special
hi def link kixEnvVar		Special
hi def link kixLabel			Type
hi def link kixFunction		Function
hi def link kixInteger		Number
hi def link kixHex			Number
hi def link kixFloat			Number
hi def link kixOperator		Operator
hi def link kixExpression		Operator

hi def link kixParenCloseError	Error
hi def link kixBrackCloseError	Error
hi def link kixStringError		Error

hi def link kixWhileError		Error
hi def link kixWhileOK		Conditional
hi def link kixDoError		Error
hi def link kixDoOK			Conditional
hi def link kixIfError		Error
hi def link kixIfOK			Conditional
hi def link kixSelectError		Error
hi def link kixSelectOK		Conditional
hi def link kixForNextError		Error
hi def link kixForNextOK		Conditional
hi def link kixForEachError		Error
hi def link kixForEachOK		Conditional


let b:current_syntax = "kix"

" vim: ts=8 sw=2
