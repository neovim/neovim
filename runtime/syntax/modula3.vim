" Vim syntax file
" Language:		Modula-3
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Timo Pedersen <dat97tpe@ludat.lth.se>
" Last Change:		2022 Oct 31

if exists("b:current_syntax")
  finish
endif

" Whitespace errors {{{1
if exists("modula3_space_errors")
  if !exists("modula3_no_trail_space_error")
    syn match modula3SpaceError display excludenl "\s\+$"
  endif
  if !exists("modula3_no_tab_space_error")
    syn match modula3SpaceError display " \+\t"me=e-1
  endif
endif

" Keywords {{{1
syn keyword modula3Keyword ANY ARRAY AS BITS BRANDED BY CASE CONST
syn keyword modula3Keyword DEFINITION EVAL EXIT EXCEPT EXCEPTION EXIT
syn keyword modula3Keyword EXPORTS FINALLY FROM GENERIC IMPORT LOCK METHOD
syn keyword modula3Keyword OF RAISE RAISES READONLY RECORD REF
syn keyword modula3Keyword RETURN SET TRY TYPE TYPECASE UNSAFE 
syn keyword modula3Keyword VALUE VAR WITH

syn match modula3keyword "\<UNTRACED\>"

" Special keywords, block delimiters etc
syn keyword modula3Block PROCEDURE FUNCTION MODULE INTERFACE REPEAT THEN
syn keyword modula3Block BEGIN END OBJECT METHODS OVERRIDES RECORD REVEAL
syn keyword modula3Block WHILE UNTIL DO TO IF FOR ELSIF ELSE LOOP

" Reserved identifiers {{{1
syn keyword modula3Identifier ABS ADR ADRSIZE BITSIZE BYTESIZE CEILING DEC
syn keyword modula3Identifier DISPOSE FIRST FLOAT FLOOR INC ISTYPE LAST
syn keyword modula3Identifier LOOPHOLE MAX MIN NARROW NEW NUMBER ORD ROUND
syn keyword modula3Identifier SUBARRAY TRUNC TYPECODE VAL

" Predefined types {{{1
syn keyword modula3Type ADDRESS BOOLEAN CARDINAL CHAR EXTENDED INTEGER
syn keyword modula3Type LONGCARD LONGINT LONGREAL MUTEX NULL REAL REFANY TEXT
syn keyword modula3Type WIDECHAR

syn match modula3Type "\<\%(UNTRACED\s\+\)\=ROOT\>"

" Operators {{{1
syn keyword modula3Operator DIV MOD
syn keyword modula3Operator IN
syn keyword modula3Operator NOT AND OR

" TODO: exclude = from declarations
if exists("modula3_operators")
  syn match modula3Operator "\^"
  syn match modula3Operator "[-+/*]"
  syn match modula3Operator "&"
  syn match modula3Operator "<=\|<:\@!\|>=\|>"
  syn match modula3Operator ":\@<!=\|#"
endif

" Literals {{{1

" Booleans
syn keyword modula3Boolean TRUE FALSE

" Nil
syn keyword modula3Nil NIL

" Numbers {{{2

" NOTE: Negated numbers are constant expressions not literals

syn case ignore

  " Integers

  syn match modula3Integer "\<\d\+L\=\>"

  if exists("modula3_number_errors")
    syn match modula3IntegerError "\<\d\d\=_\x\+L\=\>"
  endif

  let s:digits = "0123456789ABCDEF"
  for s:radix in range(2, 16)
    exe $'syn match modula3Integer "\<{s:radix}_[{s:digits[:s:radix - 1]}]\+L\=\>"'
  endfor
  unlet s:digits s:radix

  " Reals
  syn match modula3Real	 "\<\d\+\.\d\+\%([EDX][+-]\=\d\+\)\=\>"

syn case match

" Strings and characters {{{2

" String escape sequences
syn match modula3Escape "\\['"ntrf]" contained display
" TODO: limit to <= 377 (255)
syn match modula3Escape "\\\o\{3}"   contained display
syn match modula3Escape "\\\\"	     contained display

" Characters
syn match modula3Character "'\%([^']\|\\.\|\\\o\{3}\)'" contains=modula3Escape

" Strings
syn region modula3String start=+"+ end=+"+ contains=modula3Escape

" Pragmas {{{1
" EXTERNAL INLINE ASSERT TRACE FATAL UNUSED OBSOLETE CALLBACK EXPORTED PRAGMA NOWARN LINE LL LL.sup SPEC
" Documented: INLINE ASSERT TRACE FATAL UNUSED OBSOLETE NOWARN
syn region modula3Pragma start="<\*" end="\*>"

" Comments {{{1
if !exists("modula3_no_comment_fold")
  syn region modula3Comment start="(\*" end="\*)" contains=modula3Comment,@Spell fold
  syn region modula3LineCommentBlock start="^\s*(\*.*\*)\s*\n\%(^\s*(\*.*\*)\s*$\)\@=" end="^\s*(\*.*\*)\s*\n\%(^\s*(\*.*\*)\s*$\)\@!" contains=modula3Comment transparent fold keepend
else
  syn region modula3Comment start="(\*" end="\*)" contains=modula3Comment,@Spell
endif

" Syncing "{{{1
syn sync minlines=100

" Default highlighting {{{1
hi def link modula3Block	Statement
hi def link modula3Boolean	Boolean
hi def link modula3Character	Character
hi def link modula3Comment	Comment
hi def link modula3Escape	Special
hi def link modula3Identifier	Keyword
hi def link modula3Integer	Number
hi def link modula3Keyword	Statement
hi def link modula3Nil		Constant
hi def link modula3IntegerError	Error
hi def link modula3Operator	Operator
hi def link modula3Pragma	PreProc
hi def link modula3Real		Float
hi def link modula3String	String
hi def link modula3Type		Type		"}}}

let b:current_syntax = "modula3"

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
