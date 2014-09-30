" Vim syntax file
" Language: JOVIAL J73
" Version: 1.2
" Maintainer: Paul McGinnis <paulmcg@aol.com>
" Last Change: 2011/06/17
" Remark: Based on MIL-STD-1589C for JOVIAL J73 language

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

syn keyword jovialTodo TODO FIXME XXX contained

" JOVIAL beads - first digit is number of bits, [0-9A-V] is the bit value
" representing 0-31 (for 5 bits on the bead)
syn match jovialBitConstant "[1-5]B'[0-9A-V]'"

syn match jovialNumber "\<\d\+\>"

syn match jovialFloat "\d\+E[-+]\=\d\+"
syn match jovialFloat "\d\+\.\d*\(E[-+]\=\d\+\)\="
syn match jovialFloat "\.\d\+\(E[-+]\=\d\+\)\="

syn region jovialComment start=/"/ end=/"/ contains=jovialTodo
syn region jovialComment start=/%/ end=/%/ contains=jovialTodo

" JOVIAL variable names. This rule is to prevent conflicts with strings.
" Handle special case where ' character can be part of a JOVIAL variable name.
syn match jovialIdentifier "[A-Z\$][A-Z0-9'\$]\+"

syn region jovialString start="\s*'" skip=/''/ end=/'/ oneline

" JOVIAL compiler directives -- see Section 9 in MIL-STD-1589C
syn region jovialPreProc start="\s*![A-Z]\+" end=/;/

syn keyword jovialOperator AND OR NOT XOR EQV MOD

" See Section 2.1 in MIL-STD-1589C for data types
syn keyword jovialType ITEM B C P V
syn match jovialType "\<S\(,R\|,T\|,Z\)\=\>"
syn match jovialType "\<U\(,R\|,T\|,Z\)\=\>"
syn match jovialType "\<F\(,R\|,T\|,Z\)\=\>"
syn match jovialType "\<A\(,R\|,T\|,Z\)\=\>"

syn keyword jovialStorageClass STATIC CONSTANT PARALLEL BLOCK N M D W

syn keyword jovialStructure TABLE STATUS

syn keyword jovialConstant NULL

syn keyword jovialBoolean FALSE TRUE

syn keyword jovialTypedef TYPE

syn keyword jovialStatement ABORT BEGIN BY BYREF BYRES BYVAL CASE COMPOOL
syn keyword jovialStatement DEF DEFAULT DEFINE ELSE END EXIT FALLTHRU FOR
syn keyword jovialStatement GOTO IF INLINE INSTANCE LABEL LIKE OVERLAY POS
syn keyword jovialStatement PROC PROGRAM REC REF RENT REP RETURN START STOP
syn keyword jovialStatement TERM THEN WHILE

" JOVIAL extensions, see section 8.2.2 in MIL-STD-1589C
syn keyword jovialStatement CONDITION ENCAPSULATION EXPORTS FREE HANDLER IN INTERRUPT NEW
syn keyword jovialStatement PROTECTED READONLY REGISTER SIGNAL TO UPDATE WITH WRITEONLY ZONE

" implementation specific constants and functions, see section 1.4 in MIL-STD-1589C
syn keyword jovialConstant BITSINBYTE BITSINWORD LOCSINWORD
syn keyword jovialConstant BYTESINWORD BITSINPOINTER INTPRECISION
syn keyword jovialConstant FLOATPRECISION FIXEDPRECISION FLOATRADIX
syn keyword jovialConstant MAXFLOATPRECISION MAXFIXEDPRECISION
syn keyword jovialConstant MAXINTSIZE MAXBYTES MAXBITS
syn keyword jovialConstant MAXTABLESIZE MAXSTOP MINSTOP MAXSIGDIGITS
syn keyword jovialFunction BYTEPOS MAXINT MININT
syn keyword jovialFunction IMPLFLOATPRECISION IMPLFIXEDPRECISION IMPLINTSIZE
syn keyword jovialFunction MINSIZE MINFRACTION MINSCALE MINRELPRECISION
syn keyword jovialFunction MAXFLOAT MINFLOAT FLOATRELPRECISION
syn keyword jovialFunction FLOATUNDERFLOW MAXFIXED MINFIXED

" JOVIAL built-in functions
syn keyword jovialFunction LOC NEXT BIT BYTE SHIFTL SHIFTR ABS SGN BITSIZE
syn keyword jovialFunction BYTESIZE WORDSIZE LBOUND UBOUND NWDSEN FIRST
syn keyword jovialFunction LAST NENT

" Define the default highlighting.
hi def link jovialBitConstant Number
hi def link jovialBoolean Boolean
hi def link jovialComment Comment
hi def link jovialConstant Constant
hi def link jovialFloat Float
hi def link jovialFunction Function
" No color highlighting for JOVIAL identifiers. See above,
" this is to prevent confusion with JOVIAL strings
"hi def link jovialIdentifier Identifier
hi def link jovialNumber Number
hi def link jovialOperator Operator
hi def link jovialPreProc PreProc
hi def link jovialStatement Statement
hi def link jovialStorageClass StorageClass
hi def link jovialString String
hi def link jovialStructure Structure
hi def link jovialTodo Todo
hi def link jovialType Type
hi def link jovialTypedef Typedef


let b:current_syntax = "jovial"

" vim: ts=8
