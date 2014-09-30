" Vim syntax file
" Language:	HASTE - a language for VLSI IC programming
" Maintainer:	M. Tranchero - maurizio.tranchero?gmail.com
" Credits:	some parts have been taken from vhdl, verilog, and C syntax
"		files
" Version:	0.9
" Last Change:	0.9 improvement of haste numbers detection
" Change:	0.8 error matching for wrong hierarchical connections 
" Change:	0.7 added more rules to highlight pre-processor directives

" HASTE
if exists("b:current_syntax")
    finish
endif
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" case is significant
syn case match

" HASTE keywords
syn keyword hasteStatement act alias arb array begin bitvec 
syn keyword hasteStatement bitwidth boolvec broad case
syn keyword hasteStatement cast chan const dataprobe do edge
syn keyword hasteStatement else end export false ff fi file
syn keyword hasteStatement fit for forever func if import
syn keyword hasteStatement inprobe is les main narb narrow
syn keyword hasteStatement negedge od of or outprobe pas
syn keyword hasteStatement posedge probe proc ram ramreg
syn keyword hasteStatement repeat rom romreg sample sel si
syn keyword hasteStatement sign sizeof skip stop then true
syn keyword hasteStatement type until var wait wire
syn keyword hasteFutureExt Z ffe partial 
syn keyword hasteVerilog   buf reg while 

" Special match for "if", "or", and "else" since "else if"
" and other "else+if" combination shouldn't be highlighted.
" The right keyword is "or" 
syn match   hasteStatement	"\<\(if\|then\|else\|fi\)\>"
syn match   hasteNone		"\<else\s\+if\>$"
syn match   hasteNone		"\<else\s\+if\>\s"
syn match   hasteNone		"\<elseif\>\s"
syn match   hasteNone		"\<elsif\>\s"
syn match   hasteStatement	"\<\(case\|is\|si\)\>"
syn match   hasteStatement	"\<\(repeat\|until\)\>"
syn match   hasteStatement	"\<\(forever\|do\|od\)\>"
syn match   hasteStatement	"\<\(for\|do\|od\)\>"
syn match   hasteStatement	"\<\(do\|or\|od\)\>"
syn match   hasteStatement	"\<\(sel\|les\)\>"
syn match   hasteError		"\<\d\+[_a-zA-Z]\+\>"
syn match   hasteError		"\(\([[:alnum:]]\+\s*(\s\+\|)\s*,\)\)\s*\([[:alnum:]]\+\s*(\)"

" Predifined Haste types
syn keyword hasteType bool

" Values for standard Haste types
" syn match hasteVector "\'[0L1HXWZU\-\?]\'"

syn match  hasteVector "0b\"[01_]\+\""
syn match  hasteVector "0x\"[0-9a-f_]\+\""
syn match  hasteCharacter "'.'"
" syn region hasteString start=+"+  end=+"+
syn match  hasteIncluded	display contained "<[^>]*>"
syn match  hasteIncluded	display contained "<[^"]*>"
syn region hasteInclude	start="^\s*#include\>\s*" end="$" contains=hasteIncluded,hasteString

" integer numbers
syn match hasteNumber "\d\+\^[[:alnum:]]*[-+]\{0,1\}[[:alnum:]]*"
syn match hasteNumber "-\=\<\d\+\(\^[+\-]\=\d\+\)\>"
syn match hasteNumber "-\=\<\d\+\>"
" syn match hasteNumber "0*2#[01_]\+#\(\^[+\-]\=\d\+\)\="
" syn match hasteNumber "0*16#[0-9a-f_]\+#\(\^[+\-]\=\d\+\)\="
" operators
syn keyword hasteSeparators	& , . \| 
syn keyword hasteExecution	\|\| ; @
syn keyword hasteOperator	:= ? ! :
syn keyword hasteTypeConstr	"[" << >> .. "]" ~
syn keyword hasteExprOp		< <= >= > = # <> + - * == ##
syn keyword hasteMisc		( ) 0x 0b
"
syn match   hasteSeparators	"[&:\|,.]"
syn match   hasteOperator	":="
syn match   hasteOperator	":"
syn match   hasteOperator	"?"
syn match   hasteOperator	"!"
syn match   hasteExecution	"||"
syn match   hasteExecution	";"
syn match   hasteExecution	"@"
syn match   hasteType		"\[\["
syn match   hasteType		"\]\]"
syn match   hasteType		"<<"
syn match   hasteType		">>"
syn match   hasteExprOp		"<"
syn match   hasteExprOp		"<="
syn match   hasteExprOp		">="
syn match   hasteExprOp		">"
syn match   hasteExprOp		"<>"
syn match   hasteExprOp		"="
syn match   hasteExprOp		"=="
syn match   hasteExprOp		"##"
" syn match   hasteExprOp		"#"
syn match   hasteExprOp		"*"
syn match   hasteExprOp		"+"

syn region  hasteComment start="/\*" end="\*/" contains=@Spell
syn region  hasteComment start="{" end="}" contains=@Spell
syn match   hasteComment "//.*" contains=@Spell

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
hi def link hasteSpecial	Special
hi def link hasteStatement	Statement
hi def link hasteCharacter	String
hi def link hasteString		String
hi def link hasteVector		String
hi def link hasteBoolean	String
hi def link hasteComment	Comment
hi def link hasteNumber		String
hi def link hasteTime		String
hi def link hasteType		Type
hi def link hasteGlobal		Error
hi def link hasteError		Error
hi def link hasteAttribute	Type
"
hi def link hasteSeparators	Special
hi def link hasteExecution	Special
hi def link hasteTypeConstr	Special
hi def link hasteOperator	Type
hi def link hasteExprOp		Type
hi def link hasteMisc		String
hi def link hasteFutureExt 	Error
hi def link hasteVerilog	Error
hi def link hasteDefine		Macro
hi def link hasteInclude	Include
" hi def link hastePreProc	Preproc
" hi def link hastePreProcVar	Special

let b:current_syntax = "haste"

" vim: ts=8
