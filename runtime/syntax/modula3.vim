" Vim syntax file
" Language:	Modula-3
" Maintainer:	Timo Pedersen <dat97tpe@ludat.lth.se>
" Last Change:	2001 May 10

" Basic things only...
" Based on the modula 2 syntax file

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Modula-3 is case-sensitive
" syn case ignore

" Modula-3 keywords
syn keyword modula3Keyword ABS ADDRES ADR ADRSIZE AND ANY
syn keyword modula3Keyword ARRAY AS BITS BITSIZE BOOLEAN BRANDED BY BYTESIZE
syn keyword modula3Keyword CARDINAL CASE CEILING CHAR CONST DEC DEFINITION
syn keyword modula3Keyword DISPOSE DIV
syn keyword modula3Keyword EVAL EXIT EXCEPT EXCEPTION
syn keyword modula3Keyword EXIT EXPORTS EXTENDED FALSE FINALLY FIRST FLOAT
syn keyword modula3Keyword FLOOR FROM GENERIC IMPORT
syn keyword modula3Keyword IN INC INTEGER ISTYPE LAST LOCK
syn keyword modula3Keyword LONGREAL LOOPHOLE MAX METHOD MIN MOD MUTEX
syn keyword modula3Keyword NARROW NEW NIL NOT NULL NUMBER OF OR ORD RAISE
syn keyword modula3Keyword RAISES READONLY REAL RECORD REF REFANY
syn keyword modula3Keyword RETURN ROOT
syn keyword modula3Keyword ROUND SET SUBARRAY TEXT TRUE TRUNC TRY TYPE
syn keyword modula3Keyword TYPECASE TYPECODE UNSAFE UNTRACED VAL VALUE VAR WITH

" Special keywords, block delimiters etc
syn keyword modula3Block PROCEDURE FUNCTION MODULE INTERFACE REPEAT THEN
syn keyword modula3Block BEGIN END OBJECT METHODS OVERRIDES RECORD REVEAL
syn keyword modula3Block WHILE UNTIL DO TO IF FOR ELSIF ELSE LOOP

" Comments
syn region modula3Comment start="(\*" end="\*)"

" Strings
syn region modula3String start=+"+ end=+"+
syn region modula3String start=+'+ end=+'+

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" The default methods for highlighting.  Can be overridden later
hi def link modula3Keyword	Statement
hi def link modula3Block		PreProc
hi def link modula3Comment	Comment
hi def link modula3String		String


let b:current_syntax = "modula3"

"I prefer to use this...
"set ai
"vim: ts=8
