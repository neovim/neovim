" Vim syntax file
" Language:	Modula 2
" Maintainer:	pf@artcom0.north.de (Peter Funk)
"   based on original work of Bram Moolenaar <Bram@vim.org>
" Last Change:	2001 May 09

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Don't ignore case (Modula-2 is case significant). This is the default in vim

" Especially emphasize headers of procedures and modules:
syn region modula2Header matchgroup=modula2Header start="PROCEDURE " end="(" contains=modula2Ident oneline
syn region modula2Header matchgroup=modula2Header start="MODULE " end=";" contains=modula2Ident oneline
syn region modula2Header matchgroup=modula2Header start="BEGIN (\*" end="\*)" contains=modula2Ident oneline
syn region modula2Header matchgroup=modula2Header start="END " end=";" contains=modula2Ident oneline
syn region modula2Keyword start="END" end=";" contains=ALLBUT,modula2Ident oneline

" Some very important keywords which should be emphasized more than others:
syn keyword modula2AttKeyword CONST EXIT HALT RETURN TYPE VAR
" All other keywords in alphabetical order:
syn keyword modula2Keyword AND ARRAY BY CASE DEFINITION DIV DO ELSE
syn keyword modula2Keyword ELSIF EXPORT FOR FROM IF IMPLEMENTATION IMPORT
syn keyword modula2Keyword IN LOOP MOD NOT OF OR POINTER QUALIFIED RECORD
syn keyword modula2Keyword SET THEN TO UNTIL WHILE WITH

syn keyword modula2Type ADDRESS BITSET BOOLEAN CARDINAL CHAR INTEGER REAL WORD
syn keyword modula2StdFunc ABS CAP CHR DEC EXCL INC INCL ORD SIZE TSIZE VAL
syn keyword modula2StdConst FALSE NIL TRUE
" The following may be discussed, since NEW and DISPOSE are some kind of
" special builtin macro functions:
syn keyword modula2StdFunc NEW DISPOSE
" The following types are added later on and may be missing from older
" Modula-2 Compilers (they are at least missing from the original report
" by N.Wirth from March 1980 ;-)  Highlighting should apply nevertheless:
syn keyword modula2Type BYTE LONGCARD LONGINT LONGREAL PROC SHORTCARD SHORTINT
" same note applies to min and max, which were also added later to m2:
syn keyword modula2StdFunc MAX MIN
" The underscore was originally disallowed in m2 ids, it was also added later:
syn match   modula2Ident " [A-Z,a-z][A-Z,a-z,0-9,_]*" contained

" Comments may be nested in Modula-2:
syn region modula2Comment start="(\*" end="\*)" contains=modula2Comment,modula2Todo
syn keyword modula2Todo	contained TODO FIXME XXX

" Strings
syn region modula2String start=+"+ end=+"+
syn region modula2String start="'" end="'"
syn region modula2Set start="{" end="}"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link modula2Ident		Identifier
hi def link modula2StdConst	Boolean
hi def link modula2Type		Identifier
hi def link modula2StdFunc		Identifier
hi def link modula2Header		Type
hi def link modula2Keyword		Statement
hi def link modula2AttKeyword	PreProc
hi def link modula2Comment		Comment
" The following is just a matter of taste (you want to try this instead):
" hi modula2Comment term=bold ctermfg=DarkBlue guifg=Blue gui=bold
hi def link modula2Todo		Todo
hi def link modula2String		String
hi def link modula2Set		String


let b:current_syntax = "modula2"

" vim: ts=8
