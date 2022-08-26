" Vim syntax file
" Language:	MGL
" Version: 1.0
" Last Change:	2006 Feb 21
" Maintainer:  Gero Kuhlmann <gero@gkminix.han.de>
"
" $Id: mgl.vim,v 1.1 2006/02/21 22:08:20 vimboss Exp $
"
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif


syn sync lines=250

syn keyword mglBoolean		true false
syn keyword mglConditional	if else then
syn keyword mglConstant		nil
syn keyword mglPredefined	maxint
syn keyword mglLabel		case goto label
syn keyword mglOperator		to downto in of with
syn keyword mglOperator		and not or xor div mod
syn keyword mglRepeat		do for repeat while to until
syn keyword mglStatement	procedure function break continue return restart
syn keyword mglStatement	program begin end const var type
syn keyword mglStruct		record
syn keyword mglType		integer string char boolean char ipaddr array


" String
if !exists("mgl_one_line_string")
  syn region  mglString matchgroup=mglString start=+'+ end=+'+ contains=mglStringEscape
  syn region  mglString matchgroup=mglString start=+"+ end=+"+ contains=mglStringEscapeGPC
else
  "wrong strings
  syn region  mglStringError matchgroup=mglStringError start=+'+ end=+'+ end=+$+ contains=mglStringEscape
  syn region  mglStringError matchgroup=mglStringError start=+"+ end=+"+ end=+$+ contains=mglStringEscapeGPC
  "right strings
  syn region  mglString matchgroup=mglString start=+'+ end=+'+ oneline contains=mglStringEscape
  syn region  mglString matchgroup=mglString start=+"+ end=+"+ oneline contains=mglStringEscapeGPC
end
syn match   mglStringEscape	contained "''"
syn match   mglStringEscapeGPC	contained '""'


if exists("mgl_symbol_operator")
  syn match   mglSymbolOperator		"[+\-/*=\%]"
  syn match   mglSymbolOperator		"[<>]=\="
  syn match   mglSymbolOperator		"<>"
  syn match   mglSymbolOperator		":="
  syn match   mglSymbolOperator		"[()]"
  syn match   mglSymbolOperator		"\.\."
  syn match   mglMatrixDelimiter	"(."
  syn match   mglMatrixDelimiter	".)"
  syn match   mglMatrixDelimiter	"[][]"
endif

syn match  mglNumber	"-\=\<\d\+\>"
syn match  mglHexNumber	"\$[0-9a-fA-F]\+\>"
syn match  mglCharacter	"\#[0-9]\+\>"
syn match  mglIpAddr	"[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\>"

syn region mglComment	start="(\*"  end="\*)"
syn region mglComment	start="{"  end="}"
syn region mglComment	start="//"  end="$"

if !exists("mgl_no_functions")
  syn keyword mglFunction	dispose new
  syn keyword mglFunction	get load print select
  syn keyword mglFunction	odd pred succ
  syn keyword mglFunction	chr ord abs sqr
  syn keyword mglFunction	exit
  syn keyword mglOperator	at timeout
endif


syn region mglPreProc	start="(\*\$"  end="\*)"
syn region mglPreProc	start="{\$"  end="}"

syn keyword mglException	try except raise
syn keyword mglPredefined	exception


" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link mglBoolean		Boolean
hi def link mglComment		Comment
hi def link mglConditional		Conditional
hi def link mglConstant		Constant
hi def link mglException		Exception
hi def link mglFunction		Function
hi def link mglLabel		Label
hi def link mglMatrixDelimiter	Identifier
hi def link mglNumber		Number
hi def link mglHexNumber		Number
hi def link mglCharacter		Number
hi def link mglIpAddr		Number
hi def link mglOperator		Operator
hi def link mglPredefined		mglFunction
hi def link mglPreProc		PreProc
hi def link mglRepeat		Repeat
hi def link mglStatement		Statement
hi def link mglString		String
hi def link mglStringEscape	Special
hi def link mglStringEscapeGPC	Special
hi def link mglStringError		Error
hi def link mglStruct		mglStatement
hi def link mglSymbolOperator	mglOperator
hi def link mglType		Type



let b:current_syntax = "mgl"

" vim: ts=8 sw=2
