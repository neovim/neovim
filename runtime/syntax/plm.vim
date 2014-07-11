" Vim syntax file
" Language:	PL/M
" Maintainer:	Philippe Coulonges <cphil@cphil.net>
" Last change:	2003 May 11

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" PL/M is a case insensitive language
syn case ignore

syn keyword plmTodo contained	TODO FIXME XXX

" String
syn region  plmString		start=+'+  end=+'+

syn match   plmOperator		"[@=\+\-\*\/\<\>]"

syn match   plmIdentifier	"\<[a-zA-Z_][a-zA-Z0-9_]*\>"

syn match   plmDelimiter	"[();,]"

syn region  plmPreProc		start="^\s*\$\s*" skip="\\$" end="$"

" FIXME : No Number support for floats, as I'm working on an embedded
" project that doesn't use any.
syn match   plmNumber		"-\=\<\d\+\>"
syn match   plmNumber		"\<[0-9a-fA-F]*[hH]*\>"

" If you don't like tabs
"syn match plmShowTab "\t"
"syn match plmShowTabc "\t"

"when wanted, highlight trailing white space
if exists("c_space_errors")
  syn match	plmSpaceError	"\s*$"
  syn match	plmSpaceError	" \+\t"me=e-1
endif

"
  " Use the same control variable as C language for I believe
  " users will want the same behavior
if exists("c_comment_strings")
  " FIXME : don't work fine with c_comment_strings set,
  "	    which I don't care as I don't use

  " A comment can contain plmString, plmCharacter and plmNumber.
  " But a "*/" inside a plmString in a plmComment DOES end the comment!  So we
  " need to use a special type of plmString: plmCommentString, which also ends on
  " "*/", and sees a "*" at the start of the line as comment again.
  syntax match	plmCommentSkip	contained "^\s*\*\($\|\s\+\)"
  syntax region plmCommentString	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ end=+\*/+me=s-1 contains=plmSpecial,plmCommentSkip
  syntax region plmComment2String	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ end="$" contains=plmSpecial
  syntax region plmComment	start="/\*" end="\*/" contains=plmTodo,plmCommentString,plmCharacter,plmNumber,plmFloat,plmSpaceError
  syntax match  plmComment	"//.*" contains=plmTodo,plmComment2String,plmCharacter,plmNumber,plmSpaceError
else
  syn region	plmComment	start="/\*" end="\*/" contains=plmTodo,plmSpaceError
  syn match	plmComment	"//.*" contains=plmTodo,plmSpaceError
endif

syntax match	plmCommentError	"\*/"

syn keyword plmReserved	ADDRESS AND AT BASED BY BYTE CALL CASE
syn keyword plmReserved DATA DECLARE DISABLE DO DWORD
syn keyword plmReserved	ELSE ENABLE END EOF EXTERNAL
syn keyword plmReserved GO GOTO HALT IF INITIAL INTEGER INTERRUPT
syn keyword plmReserved LABEL LITERALLY MINUS MOD NOT OR
syn keyword plmReserved PLUS POINTER PROCEDURE PUBLIC
syn keyword plmReserved REAL REENTRANT RETURN SELECTOR STRUCTURE
syn keyword plmReserved THEN TO WHILE WORD XOR
syn keyword plm386Reserved CHARINT HWORD LONGINT OFFSET QWORD SHORTINT

syn keyword plmBuiltIn ABS ADJUSTRPL BLOCKINPUT BLOCKINWORD BLOCKOUTPUT
syn keyword plmBuiltIn BLOCKOUTWORD BUILPTR CARRY CAUSEINTERRUPT CMPB
syn keyword plmBuiltIn CMPW DEC DOUBLE FINDB FINDRB FINDRW FINDW FIX
syn keyword plmBuiltIn FLAGS FLOAT GETREALERROR HIGH IABS INITREALMATHUNIT
syn keyword plmBuiltIn INPUT INT INWORD LAST LOCKSET LENGTH LOW MOVB MOVE
syn keyword plmBuiltIn MOVRB MOVRW MOVW NIL OUTPUT OUTWORD RESTOREREALSTATUS
syn keyword plmBuiltIn ROL ROR SAL SAVEREALSTATUS SCL SCR SELECTOROF SETB
syn keyword plmBuiltIn SETREALMODE SETW SHL SHR SIGN SIGNED SIZE SKIPB
syn keyword plmBuiltIn SKIPRB SKIPRW SKIPW STACKBASE STACKPTR TIME SIZE
syn keyword plmBuiltIn UNSIGN XLAT ZERO
syn keyword plm386BuiltIn INTERRUPT SETINTERRUPT
syn keyword plm286BuiltIn CLEARTASKSWITCHEDFLAG GETACCESSRIGHTS
syn keyword plm286BuiltIn GETSEGMENTLIMIT LOCALTABLE MACHINESTATUS
syn keyword plm286BuiltIn OFFSETOF PARITY RESTOREGLOBALTABLE
syn keyword plm286BuiltIn RESTOREINTERRUPTTABLE SAVEGLOBALTABLE
syn keyword plm286BuiltIn SAVEINTERRUPTTABLE SEGMENTREADABLE
syn keyword plm286BuiltIn SEGMENTWRITABLE TASKREGISTER WAITFORINTERRUPT
syn keyword plm386BuiltIn CONTROLREGISTER DEBUGREGISTER FINDHW
syn keyword plm386BuiltIn FINDRHW INHWORD MOVBIT MOVRBIT MOVHW MOVRHW
syn keyword plm386BuiltIn OUTHWORD SCANBIT SCANRBIT SETHW SHLD SHRD
syn keyword plm386BuiltIn SKIPHW SKIPRHW TESTREGISTER
syn keyword plm386w16BuiltIn BLOCKINDWORD BLOCKOUTDWORD CMPD FINDD
syn keyword plm386w16BuiltIn FINDRD INDWORD MOVD MOVRD OUTDWORD
syn keyword plm386w16BuiltIn SETD SKIPD SKIPRD

syn sync lines=50

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_plm_syntax_inits")
  if version < 508
    let did_plm_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

 " The default methods for highlighting.  Can be overridden later
"  HiLink plmLabel			Label
"  HiLink plmConditional		Conditional
"  HiLink plmRepeat			Repeat
  HiLink plmTodo			Todo
  HiLink plmNumber			Number
  HiLink plmOperator			Operator
  HiLink plmDelimiter			Operator
  "HiLink plmShowTab			Error
  "HiLink plmShowTabc			Error
  HiLink plmIdentifier			Identifier
  HiLink plmBuiltIn			Statement
  HiLink plm286BuiltIn			Statement
  HiLink plm386BuiltIn			Statement
  HiLink plm386w16BuiltIn		Statement
  HiLink plmReserved			Statement
  HiLink plm386Reserved			Statement
  HiLink plmPreProc			PreProc
  HiLink plmCommentError		plmError
  HiLink plmCommentString		plmString
  HiLink plmComment2String		plmString
  HiLink plmCommentSkip			plmComment
  HiLink plmString			String
  HiLink plmComment			Comment

  delcommand HiLink
endif

let b:current_syntax = "plm"

" vim: ts=8 sw=2

