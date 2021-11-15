" This source file is part of the motoko.org open source project
"
" Copyright (c) 2014 - 2020 Apple Inc. and the motoko project authors
" Licensed under Apache License v2.0 with Runtime Library Exception
"
" See https://swift.org/LICENSE.txt for license information
" See https://swift.org/CONTRIBUTORS.txt for the list of motoko project authors
"
" Vim syntax file
" Language: motoko
" Maintainer: Nicolas Martin <martinni39@gmail.com.com>
" Last Change: 2021 Nov 14

if exists("b:current_syntax")
    finish
endif

let s:keepcpo = &cpo
set cpo&vim

syn keyword motokoKeyword
      \ break
      \ case
      \ catch
      \ continue
      \ default
      \ defer
      \ do
      \ else
      \ fallthrough
      \ for
      \ guard
      \ if
      \ in
      \ repeat
      \ return
      \ switch
      \ throw
      \ try
      \ where
      \ while
syn match motokoMultiwordKeyword
      \ "indirect case"

syn keyword motokoCoreTypes
      \ Any
      \ AnyObject

syn keyword motokoImport skipwhite skipempty nextgroup=motokoImportModule
      \ import

syn keyword motokoDefinitionModifier
      \ convenience
      \ dynamic
      \ fileprivate
      \ final
      \ internal
      \ lazy
      \ nonmutating
      \ open
      \ override
      \ prefix
      \ private
      \ public
      \ required
      \ rethrows
      \ static
      \ throws
      \ weak

syn keyword motokoInOutKeyword skipwhite skipempty nextgroup=motokoTypeName
      \ inout

syn keyword motokoIdentifierKeyword
      \ Self
      \ metatype
      \ self
      \ super

syn keyword motokoFuncKeywordGeneral skipwhite skipempty nextgroup=motokoTypeParameters
      \ init

syn keyword motokoFuncKeyword
      \ deinit
      \ subscript

syn keyword motokoScope
      \ autoreleasepool

syn keyword motokoMutating skipwhite skipempty nextgroup=motokoFuncDefinition
      \ mutating
syn keyword motokoFuncDefinition skipwhite skipempty nextgroup=motokoTypeName,motokoOperator
      \ func

syn keyword motokoTypeDefinition skipwhite skipempty nextgroup=motokoTypeName
      \ class
      \ enum
      \ extension
      \ operator
      \ precedencegroup
      \ protocol
      \ struct

syn keyword motokoTypeAliasDefinition skipwhite skipempty nextgroup=motokoTypeAliasName
      \ associatedtype
      \ typealias

syn match motokoMultiwordTypeDefinition skipwhite skipempty nextgroup=motokoTypeName
      \ "indirect enum"

syn keyword motokoVarDefinition skipwhite skipempty nextgroup=motokoVarName
      \ let
      \ var

syn keyword motokoLabel
      \ get
      \ set
      \ didSet
      \ willSet

syn keyword motokoBoolean
      \ false
      \ true

syn keyword motokoNil
      \ nil

syn match motokoImportModule contained nextgroup=motokoImportComponent
      \ /\<[A-Za-z_][A-Za-z_0-9]*\>/
syn match motokoImportComponent contained nextgroup=motokoImportComponent
      \ /\.\<[A-Za-z_][A-Za-z_0-9]*\>/

syn match motokoTypeAliasName contained skipwhite skipempty nextgroup=motokoTypeAliasValue
      \ /\<[A-Za-z_][A-Za-z_0-9]*\>/
syn match motokoTypeName contained skipwhite skipempty nextgroup=motokoTypeParameters
      \ /\<[A-Za-z_][A-Za-z_0-9\.]*\>/
syn match motokoVarName contained skipwhite skipempty nextgroup=motokoTypeDeclaration
      \ /\<[A-Za-z_][A-Za-z_0-9]*\>/
syn match motokoImplicitVarName
      \ /\$\<[A-Za-z_0-9]\+\>/

" TypeName[Optionality]?
syn match motokoType contained skipwhite skipempty nextgroup=motokoTypeParameters
      \ /\<[A-Za-z_][A-Za-z_0-9\.]*\>[!?]\?/
" [Type:Type] (dictionary) or [Type] (array)
syn region motokoType contained contains=motokoTypePair,motokoType
      \ matchgroup=Delimiter start=/\[/ end=/\]/
syn match motokoTypePair contained skipwhite skipempty nextgroup=motokoTypeParameters,motokoTypeDeclaration
      \ /\<[A-Za-z_][A-Za-z_0-9\.]*\>[!?]\?/
" (Type[, Type]) (tuple)
" FIXME: we should be able to use skip="," and drop motokoParamDelim
syn region motokoType contained contains=motokoType,motokoParamDelim
      \ matchgroup=Delimiter start="[^@]\?(" end=")" matchgroup=NONE skip=","
syn match motokoParamDelim contained
      \ /,/
" <Generic Clause> (generics)
syn region motokoTypeParameters contained contains=motokoVarName,motokoConstraint
      \ matchgroup=Delimiter start="<" end=">" matchgroup=NONE skip=","
syn keyword motokoConstraint contained
      \ where

syn match motokoTypeAliasValue skipwhite skipempty nextgroup=motokoType
      \ /=/
syn match motokoTypeDeclaration skipwhite skipempty nextgroup=motokoType,motokoInOutKeyword
      \ /:/
syn match motokoTypeDeclaration skipwhite skipempty nextgroup=motokoType
      \ /->/

syn match motokoKeyword
      \ /\<case\>/
syn region motokoCaseLabelRegion
      \ matchgroup=motokoKeyword start=/\<case\>/ matchgroup=Delimiter end=/:/ oneline contains=TOP
syn region motokoDefaultLabelRegion
      \ matchgroup=motokoKeyword start=/\<default\>/ matchgroup=Delimiter end=/:/ oneline

syn region motokoParenthesisRegion contains=TOP
      \ matchgroup=NONE start=/(/ end=/)/

syn region motokoString contains=motokoInterpolationRegion
      \ start=/"/ skip=/\\\\\|\\"/ end=/"/
syn region motokoInterpolationRegion contained contains=TOP
      \ matchgroup=motokoInterpolation start=/\\(/ end=/)/
syn region motokoComment contains=motokoComment,motokoLineComment,motokoTodo
      \ start="/\*" end="\*/"
syn region motokoLineComment contains=motokoComment,motokoTodo
      \ start="//" end="$"

syn match motokoDecimal
      \ /[+\-]\?\<\([0-9][0-9_]*\)\([.][0-9_]*\)\?\([eE][+\-]\?[0-9][0-9_]*\)\?\>/
syn match motokoHex
      \ /[+\-]\?\<0x[0-9A-Fa-f][0-9A-Fa-f_]*\(\([.][0-9A-Fa-f_]*\)\?[pP][+\-]\?[0-9][0-9_]*\)\?\>/
syn match motokoOct
      \ /[+\-]\?\<0o[0-7][0-7_]*\>/
syn match motokoBin
      \ /[+\-]\?\<0b[01][01_]*\>/

syn match motokoOperator skipwhite skipempty nextgroup=motokoTypeParameters
      \ "\.\@<!\.\.\.\@!\|[/=\-+*%<>!&|^~]\@<!\(/[/*]\@![/=\-+*%<>!&|^~]*\|*/\@![/=\-+*%<>!&|^~]*\|->\@![/=\-+*%<>!&|^~]*\|[=+%<>!&|^~][/=\-+*%<>!&|^~]*\)"
syn match motokoOperator skipwhite skipempty nextgroup=motokoTypeParameters
      \ "\.\.[<.]"

syn match motokoChar
      \ /'\([^'\\]\|\\\(["'tnr0\\]\|x[0-9a-fA-F]\{2}\|u[0-9a-fA-F]\{4}\|U[0-9a-fA-F]\{8}\)\)'/

syn match motokoTupleIndexNumber contains=motokoDecimal
      \ /\.[0-9]\+/
syn match motokoDecimal contained
      \ /[0-9]\+/

syn match motokoPreproc
      \ /#\(\<column\>\|\<dsohandle\>\|\<file\>\|\<line\>\|\<function\>\)/
syn match motokoPreproc
      \ /^\s*#\(\<if\>\|\<else\>\|\<elseif\>\|\<endif\>\|\<error\>\|\<warning\>\)/
syn region motokoPreprocFalse
      \ start="^\s*#\<if\>\s\+\<false\>" end="^\s*#\(\<else\>\|\<elseif\>\|\<endif\>\)"

syn match motokoAttribute
      \ /@\<\w\+\>/ skipwhite skipempty nextgroup=motokoType,motokoTypeDefinition

syn keyword motokoTodo MARK TODO FIXME contained

syn match motokoCastOp skipwhite skipempty nextgroup=motokoType,motokoCoreTypes
      \ "\<is\>"
syn match motokoCastOp skipwhite skipempty nextgroup=motokoType,motokoCoreTypes
      \ "\<as\>[!?]\?"

syn match motokoNilOps
      \ "??"

syn region motokoReservedIdentifier oneline
      \ start=/`/ end=/`/

hi def link motokoImport Include
hi def link motokoImportModule Title
hi def link motokoImportComponent Identifier
hi def link motokoKeyword Statement
hi def link motokoCoreTypes Type
hi def link motokoMultiwordKeyword Statement
hi def link motokoTypeDefinition Define
hi def link motokoMultiwordTypeDefinition Define
hi def link motokoType Type
hi def link motokoTypePair Type
hi def link motokoTypeAliasName Identifier
hi def link motokoTypeName Function
hi def link motokoConstraint Special
hi def link motokoFuncDefinition Define
hi def link motokoDefinitionModifier Operator
hi def link motokoInOutKeyword Define
hi def link motokoFuncKeyword Function
hi def link motokoFuncKeywordGeneral Function
hi def link motokoTypeAliasDefinition Define
hi def link motokoVarDefinition Define
hi def link motokoVarName Identifier
hi def link motokoImplicitVarName Identifier
hi def link motokoIdentifierKeyword Identifier
hi def link motokoTypeAliasValue Delimiter
hi def link motokoTypeDeclaration Delimiter
hi def link motokoTypeParameters Delimiter
hi def link motokoBoolean Boolean
hi def link motokoString String
hi def link motokoInterpolation Special
hi def link motokoComment Comment
hi def link motokoLineComment Comment
hi def link motokoDecimal Number
hi def link motokoHex Number
hi def link motokoOct Number
hi def link motokoBin Number
hi def link motokoOperator Function
hi def link motokoChar Character
hi def link motokoLabel Operator
hi def link motokoMutating Statement
hi def link motokoPreproc PreCondit
hi def link motokoPreprocFalse Comment
hi def link motokoAttribute Type
hi def link motokoTodo Todo
hi def link motokoNil Constant
hi def link motokoCastOp Operator
hi def link motokoNilOps Operator
hi def link motokoScope PreProc

let b:current_syntax = "motoko"

let &cpo = s:keepcpo
unlet s:keepcpo
