" Vim syntax file
" Language:	MGL
" Version: 1.0
" Last Change:	2006 Feb 21
" Maintainer:  Gero Kuhlmann <gero@gkminix.han.de>
"
" $Id: mgl.vim,v 1.1 2006/02/21 22:08:20 vimboss Exp $
"
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_mgl_syn_inits")
  if version < 508
    let did_mgl_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink mglBoolean		Boolean
  HiLink mglComment		Comment
  HiLink mglConditional		Conditional
  HiLink mglConstant		Constant
  HiLink mglException		Exception
  HiLink mglFunction		Function
  HiLink mglLabel		Label
  HiLink mglMatrixDelimiter	Identifier
  HiLink mglNumber		Number
  HiLink mglHexNumber		Number
  HiLink mglCharacter		Number
  HiLink mglIpAddr		Number
  HiLink mglOperator		Operator
  HiLink mglPredefined		mglFunction
  HiLink mglPreProc		PreProc
  HiLink mglRepeat		Repeat
  HiLink mglStatement		Statement
  HiLink mglString		String
  HiLink mglStringEscape	Special
  HiLink mglStringEscapeGPC	Special
  HiLink mglStringError		Error
  HiLink mglStruct		mglStatement
  HiLink mglSymbolOperator	mglOperator
  HiLink mglType		Type

  delcommand HiLink
endif


let b:current_syntax = "mgl"

" vim: ts=8 sw=2
