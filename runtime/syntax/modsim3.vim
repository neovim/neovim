" Vim syntax file
" Language:	Modsim III, by compuware corporation (www.compuware.com)
" Maintainer:	Philipp Jocham <flip@sbox.tu-graz.ac.at>
" Extension:	*.mod
" Last Change:	2001 May 10
"
" 2001 March 24:
"  - Modsim III is a registered trademark from compuware corporation
"  - made compatible with Vim 6.0
"
" 1999 Apr 22 : Changed modsim3Literal from region to match
"
" very basic things only (based on the modula2 and c files).

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif


" syn case match " case sensitiv match is default

" A bunch of keywords
syn keyword modsim3Keyword ACTID ALL AND AS ASK
syn keyword modsim3Keyword BY CALL CASE CLASS CONST DIV
syn keyword modsim3Keyword DOWNTO DURATION ELSE ELSIF EXIT FALSE FIXED FOR
syn keyword modsim3Keyword FOREACH FORWARD IF IN INHERITED INOUT
syn keyword modsim3Keyword INTERRUPT LOOP
syn keyword modsim3Keyword MOD MONITOR NEWVALUE
syn keyword modsim3Keyword NONMODSIM NOT OBJECT OF ON OR ORIGINAL OTHERWISE OUT
syn keyword modsim3Keyword OVERRIDE PRIVATE PROTO REPEAT
syn keyword modsim3Keyword RETURN REVERSED SELF STRERR TELL
syn keyword modsim3Keyword TERMINATE THISMETHOD TO TRUE TYPE UNTIL VALUE VAR
syn keyword modsim3Keyword WAIT WAITFOR WHEN WHILE WITH

" Builtin functions and procedures
syn keyword modsim3Builtin ABS ACTIVATE ADDMONITOR CAP CHARTOSTR CHR CLONE
syn keyword modsim3Builtin DEACTIVATE DEC DISPOSE FLOAT GETMONITOR HIGH INC
syn keyword modsim3Builtin INPUT INSERT INTTOSTR ISANCESTOR LOW LOWER MAX MAXOF
syn keyword modsim3Builtin MIN MINOF NEW OBJTYPEID OBJTYPENAME OBJVARID ODD
syn keyword modsim3Builtin ONERROR ONEXIT ORD OUTPUT POSITION PRINT REALTOSTR
syn keyword modsim3Builtin REPLACE REMOVEMONITOR ROUND SCHAR SIZEOF SPRINT
syn keyword modsim3Builtin STRLEN STRTOCHAR STRTOINT STRTOREAL SUBSTR TRUNC
syn keyword modsim3Builtin UPDATEVALUE UPPER VAL

syn keyword modsim3BuiltinNoParen HALT TRACE

" Special keywords
syn keyword modsim3Block PROCEDURE METHOD MODULE MAIN DEFINITION IMPLEMENTATION
syn keyword modsim3Block BEGIN END

syn keyword modsim3Include IMPORT FROM

syn keyword modsim3Type ANYARRAY ANYOBJ ANYREC ARRAY BOOLEAN CHAR INTEGER
syn keyword modsim3Type LMONITORED LRMONITORED NILARRAY NILOBJ NILREC REAL
syn keyword modsim3Type RECORD RMONITOR RMONITORED STRING

" catch errros cause by wrong parenthesis
" slight problem with "( *)" or "(* )". Hints?
syn region modsim3Paren	transparent start='(' end=')' contains=ALLBUT,modsim3ParenError
syn match modsim3ParenError ")"

" Comments
syn region modsim3Comment1 start="{" end="}" contains=modsim3Comment1,modsim3Comment2
syn region modsim3Comment2 start="(\*" end="\*)" contains=modsim3Comment1,modsim3Comment2
" highlighting is wrong for constructs like "{  (*  }  *)",
" which are allowed in Modsim III, but
" I think something like that shouldn't be used anyway.

" Strings
syn region modsim3String start=+"+ end=+"+

" Literals
"syn region modsim3Literal start=+'+ end=+'+
syn match modsim3Literal "'[^']'\|''''"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" The default methods for highlighting.  Can be overridden later
hi def link modsim3Keyword	Statement
hi def link modsim3Block		Statement
hi def link modsim3Comment1	Comment
hi def link modsim3Comment2	Comment
hi def link modsim3String		String
hi def link modsim3Literal	Character
hi def link modsim3Include	Statement
hi def link modsim3Type		Type
hi def link modsim3ParenError	Error
hi def link modsim3Builtin	Function
hi def link modsim3BuiltinNoParen	Function


let b:current_syntax = "modsim3"

" vim: ts=8 sw=2

