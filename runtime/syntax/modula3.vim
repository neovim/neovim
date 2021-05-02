" Vim syntax file
" Language:		Modula-3
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Timo Pedersen <dat97tpe@ludat.lth.se>
" Last Change:		2021 Apr 08

if exists("b:current_syntax")
  finish
endif

" Modula-3 keywords
syn keyword modula3Keyword ANY ARRAY AS BITS BRANDED BY CASE CONST DEFINITION
syn keyword modula3Keyword EVAL EXIT EXCEPT EXCEPTION EXIT EXPORTS FINALLY
syn keyword modula3Keyword FROM GENERIC IMPORT LOCK METHOD OF RAISE RAISES
syn keyword modula3Keyword READONLY RECORD REF RETURN SET TRY TYPE TYPECASE
syn keyword modula3Keyword UNSAFE VALUE VAR WITH

syn match modula3keyword "\<UNTRACED\>"

" Special keywords, block delimiters etc
syn keyword modula3Block PROCEDURE FUNCTION MODULE INTERFACE REPEAT THEN
syn keyword modula3Block BEGIN END OBJECT METHODS OVERRIDES RECORD REVEAL
syn keyword modula3Block WHILE UNTIL DO TO IF FOR ELSIF ELSE LOOP

" Reserved identifiers
syn keyword modula3Identifier ABS ADR ADRSIZE BITSIZE BYTESIZE CEILING DEC
syn keyword modula3Identifier DISPOSE FIRST FLOAT FLOOR INC ISTYPE LAST
syn keyword modula3Identifier LOOPHOLE MAX MIN NARROW NEW NUMBER ORD ROUND
syn keyword modula3Identifier SUBARRAY TRUNC TYPECODE VAL

" Predefined types
syn keyword modula3Type ADDRESS BOOLEAN CARDINAL CHAR EXTENDED INTEGER
syn keyword modula3Type LONGCARD LONGINT LONGREAL MUTEX NULL REAL REFANY TEXT
syn keyword modula3Type WIDECHAR

syn match modula3Type "\<\%(UNTRACED\s\+\)\=ROOT\>"

" Operators
syn keyword modulaOperator DIV MOD IN AND OR NOT

if exists("modula3_operators")
  syn match modula3Operator "\^"
  syn match modula3Operator "+\|-\|\*\|/\|&"
  " TODO: need to exclude = in procedure definitions
  syn match modula3Operator "<=\|<\|>=\|>\|:\@<!=\|#"
endif

" Booleans
syn keyword modula3Boolean TRUE FALSE

" Nil
syn keyword modula3Nil NIL

" Integers
syn match modula3Integer "\<\d\+L\=\>"
syn match modula3Integer "\<\d\d\=_\x\+L\=\>"

" Reals
syn match modula3Real	 "\c\<\d\+\.\d\+\%([EDX][+-]\=\d\+\)\=\>"

" String escape sequences
syn match modula3Escape "\\['"ntrf]" contained display
syn match modula3Escape "\\\o\{3}"   contained display
syn match modula3Escape "\\\\"	     contained display

" Characters
syn match modula3Character "'\%([^']\|\\.\|\\\o\{3}\)'" contains=modula3Escape

" Strings
syn region modula3String start=+"+ end=+"+ contains=modula3Escape

" Pragmas
syn region modula3Pragma start="<\*" end="\*>"

" Comments
syn region modula3Comment start="(\*" end="\*)" contains=modula3Comment,@Spell

" Default highlighting
hi def link modula3Block	Statement
hi def link modula3Boolean	Boolean
hi def link modula3Character	Character
hi def link modula3Comment	Comment
hi def link modula3Escape	Special
hi def link modula3Identifier	Keyword
hi def link modula3Integer	Number
hi def link modula3Keyword	Statement
hi def link modula3Nil		Constant
hi def link modula3Operator	Operator
hi def link modula3Pragma	PreProc
hi def link modula3Real		Float
hi def link modula3String	String
hi def link modula3Type		Type

let b:current_syntax = "modula3"

" vim: nowrap sw=2 sts=2 ts=8 noet:
