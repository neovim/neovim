" Vim syntax file
" Language:		Clean
" Author:		Pieter van Engelen <pietere@sci.kun.nl>
" Co-Author:	Arthur van Leeuwen <arthurvl@sci.kun.nl>
" Last Change:	2013 Oct 15 by Jurriën Stutterheim

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Some Clean-keywords
syn keyword cleanConditional if case
syn keyword cleanLabel let! with where in of
syn keyword cleanSpecial Start
syn keyword cleanKeyword infixl infixr infix
syn keyword cleanBasicType Int Real Char Bool String
syn keyword cleanSpecialType World ProcId Void Files File
syn keyword cleanModuleSystem module implementation definition system
syn keyword cleanTypeClass class instance export

" Import highlighting
syn region cleanIncludeRegion start="^\s*\(from\|import\|\s\+\(as\|qualified\)\)" end="\n" contains=cleanIncludeKeyword keepend
syn keyword cleanIncludeKeyword contained from import as qualified

" To do some Denotation Highlighting
syn keyword cleanBoolDenot True False
syn region cleanStringDenot start=+"+ skip=+\(\(\\\\\)\+\|\\"\)+ end=+"+ display
syn match cleanCharDenot "'\(\\\\\|\\'\|[^'\\]\)\+'" display
syn match cleanIntegerDenot "[\~+-]\?\<\(\d\+\|0[0-7]\+\|0x[0-9A-Fa-f]\+\)\>" display
syn match cleanRealDenot "[\~+-]\?\d\+\.\d\+\(E[\~+-]\?\d\+\)\?" display

" To highlight the use of lists, tuples and arrays
syn region cleanList start="\[" end="\]" contains=ALL
syn region cleanRecord start="{" end="}" contains=ALL
syn region cleanArray start="{:" end=":}" contains=ALL
syn match cleanTuple "([^=]*,[^=]*)" contains=ALL

" To do some Comment Highlighting
syn region cleanComment start="/\*"  end="\*/" contains=cleanComment,cleanTodo fold
syn region cleanComment start="//.*" end="$" display contains=cleanTodo
syn keyword cleanTodo TODO FIXME XXX contained

" Now for some useful type definition recognition
syn match cleanFuncTypeDef "\([a-zA-Z].*\|(\=[-~@#$%^?!+*<>\/|&=:]\+)\=\)\s*\(infix[lr]\=\)\=\s*\d\=\s*::.*->.*" contains=cleanSpecial,cleanBasicType,cleanSpecialType,cleanKeyword


" Define the default highlighting.
" Only when an item doesn't have highlighting yet

 " Comments
 hi def link cleanComment      Comment
 " Constants and denotations
 hi def link cleanStringDenot  String
 hi def link cleanCharDenot    Character
 hi def link cleanIntegerDenot Number
 hi def link cleanBoolDenot    Boolean
 hi def link cleanRealDenot    Float
 " Identifiers
 " Statements
 hi def link cleanTypeClass    Keyword
 hi def link cleanConditional  Conditional
 hi def link cleanLabel		Label
 hi def link cleanKeyword      Keyword
 " Generic Preprocessing
 hi def link cleanIncludeKeyword      Include
 hi def link cleanModuleSystem PreProc
 " Type
 hi def link cleanBasicType    Type
 hi def link cleanSpecialType  Type
 hi def link cleanFuncTypeDef  Typedef
 " Special
 hi def link cleanSpecial      Special
 hi def link cleanList			Special
 hi def link cleanArray		Special
 hi def link cleanRecord		Special
 hi def link cleanTuple		Special
 " Error
 " Todo
 hi def link cleanTodo         Todo


let b:current_syntax = "clean"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=4
