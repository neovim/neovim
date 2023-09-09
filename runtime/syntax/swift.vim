" This source file is part of the Swift.org open source project
"
" Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
" Licensed under Apache License v2.0 with Runtime Library Exception
"
" See https://swift.org/LICENSE.txt for license information
" See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
"
" Vim syntax file
" Language: swift
" Maintainer: Joe Groff <jgroff@apple.com>
" Last Change: 2018 Jan 21
"
" Vim maintainer: Emir SARI <bitigchi@me.com>

if exists("b:current_syntax")
    finish
endif

let s:keepcpo = &cpo
set cpo&vim

syn keyword swiftKeyword
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
syn match swiftMultiwordKeyword
      \ "indirect case"

syn keyword swiftCoreTypes
      \ Any
      \ AnyObject

syn keyword swiftImport skipwhite skipempty nextgroup=swiftImportModule
      \ import

syn keyword swiftDefinitionModifier
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

syn keyword swiftInOutKeyword skipwhite skipempty nextgroup=swiftTypeName
      \ inout

syn keyword swiftIdentifierKeyword
      \ Self
      \ metatype
      \ self
      \ super

syn keyword swiftFuncKeywordGeneral skipwhite skipempty nextgroup=swiftTypeParameters
      \ init

syn keyword swiftFuncKeyword
      \ deinit
      \ subscript

syn keyword swiftScope
      \ autoreleasepool

syn keyword swiftMutating skipwhite skipempty nextgroup=swiftFuncDefinition
      \ mutating
syn keyword swiftFuncDefinition skipwhite skipempty nextgroup=swiftTypeName,swiftOperator
      \ func

syn keyword swiftTypeDefinition skipwhite skipempty nextgroup=swiftTypeName
      \ class
      \ enum
      \ extension
      \ operator
      \ precedencegroup
      \ protocol
      \ struct

syn keyword swiftTypeAliasDefinition skipwhite skipempty nextgroup=swiftTypeAliasName
      \ associatedtype
      \ typealias

syn match swiftMultiwordTypeDefinition skipwhite skipempty nextgroup=swiftTypeName
      \ "indirect enum"

syn keyword swiftVarDefinition skipwhite skipempty nextgroup=swiftVarName
      \ let
      \ var

syn keyword swiftLabel
      \ get
      \ set
      \ didSet
      \ willSet

syn keyword swiftBoolean
      \ false
      \ true

syn keyword swiftNil
      \ nil

syn match swiftImportModule contained nextgroup=swiftImportComponent
      \ /\<[A-Za-z_][A-Za-z_0-9]*\>/
syn match swiftImportComponent contained nextgroup=swiftImportComponent
      \ /\.\<[A-Za-z_][A-Za-z_0-9]*\>/

syn match swiftTypeAliasName contained skipwhite skipempty nextgroup=swiftTypeAliasValue
      \ /\<[A-Za-z_][A-Za-z_0-9]*\>/
syn match swiftTypeName contained skipwhite skipempty nextgroup=swiftTypeParameters
      \ /\<[A-Za-z_][A-Za-z_0-9\.]*\>/
syn match swiftVarName contained skipwhite skipempty nextgroup=swiftTypeDeclaration
      \ /\<[A-Za-z_][A-Za-z_0-9]*\>/
syn match swiftImplicitVarName
      \ /\$\<[A-Za-z_0-9]\+\>/

" TypeName[Optionality]?
syn match swiftType contained skipwhite skipempty nextgroup=swiftTypeParameters
      \ /\<[A-Za-z_][A-Za-z_0-9\.]*\>[!?]\?/
" [Type:Type] (dictionary) or [Type] (array)
syn region swiftType contained contains=swiftTypePair,swiftType
      \ matchgroup=Delimiter start=/\[/ end=/\]/
syn match swiftTypePair contained skipwhite skipempty nextgroup=swiftTypeParameters,swiftTypeDeclaration
      \ /\<[A-Za-z_][A-Za-z_0-9\.]*\>[!?]\?/
" (Type[, Type]) (tuple)
" FIXME: we should be able to use skip="," and drop swiftParamDelim
syn region swiftType contained contains=swiftType,swiftParamDelim
      \ matchgroup=Delimiter start="[^@]\?(" end=")" matchgroup=NONE skip=","
syn match swiftParamDelim contained
      \ /,/
" <Generic Clause> (generics)
syn region swiftTypeParameters contained contains=swiftVarName,swiftConstraint
      \ matchgroup=Delimiter start="<" end=">" matchgroup=NONE skip=","
syn keyword swiftConstraint contained
      \ where

syn match swiftTypeAliasValue skipwhite skipempty nextgroup=swiftType
      \ /=/
syn match swiftTypeDeclaration skipwhite skipempty nextgroup=swiftType,swiftInOutKeyword
      \ /:/
syn match swiftTypeDeclaration skipwhite skipempty nextgroup=swiftType
      \ /->/

syn match swiftKeyword
      \ /\<case\>/
syn region swiftCaseLabelRegion
      \ matchgroup=swiftKeyword start=/\<case\>/ matchgroup=Delimiter end=/:/ oneline contains=TOP
syn region swiftDefaultLabelRegion
      \ matchgroup=swiftKeyword start=/\<default\>/ matchgroup=Delimiter end=/:/ oneline

syn region swiftParenthesisRegion contains=TOP
      \ matchgroup=NONE start=/(/ end=/)/

syn region swiftString contains=swiftInterpolationRegion
      \ start=/"/ skip=/\\\\\|\\"/ end=/"/
syn region swiftInterpolationRegion contained contains=TOP
      \ matchgroup=swiftInterpolation start=/\\(/ end=/)/
syn region swiftComment contains=swiftComment,swiftLineComment,swiftTodo
      \ start="/\*" end="\*/"
syn region swiftLineComment contains=swiftComment,swiftTodo
      \ start="//" end="$"

syn match swiftDecimal
      \ /[+\-]\?\<\([0-9][0-9_]*\)\([.][0-9_]*\)\?\([eE][+\-]\?[0-9][0-9_]*\)\?\>/
syn match swiftHex
      \ /[+\-]\?\<0x[0-9A-Fa-f][0-9A-Fa-f_]*\(\([.][0-9A-Fa-f_]*\)\?[pP][+\-]\?[0-9][0-9_]*\)\?\>/
syn match swiftOct
      \ /[+\-]\?\<0o[0-7][0-7_]*\>/
syn match swiftBin
      \ /[+\-]\?\<0b[01][01_]*\>/

syn match swiftOperator skipwhite skipempty nextgroup=swiftTypeParameters
      \ "\.\@<!\.\.\.\@!\|[/=\-+*%<>!&|^~]\@<!\(/[/*]\@![/=\-+*%<>!&|^~]*\|*/\@![/=\-+*%<>!&|^~]*\|->\@![/=\-+*%<>!&|^~]*\|[=+%<>!&|^~][/=\-+*%<>!&|^~]*\)"
syn match swiftOperator skipwhite skipempty nextgroup=swiftTypeParameters
      \ "\.\.[<.]"

syn match swiftChar
      \ /'\([^'\\]\|\\\(["'tnr0\\]\|x[0-9a-fA-F]\{2}\|u[0-9a-fA-F]\{4}\|U[0-9a-fA-F]\{8}\)\)'/

syn match swiftTupleIndexNumber contains=swiftDecimal
      \ /\.[0-9]\+/
syn match swiftDecimal contained
      \ /[0-9]\+/

syn match swiftPreproc
      \ /#\(\<column\>\|\<dsohandle\>\|\<file\>\|\<line\>\|\<function\>\)/
syn match swiftPreproc
      \ /^\s*#\(\<if\>\|\<else\>\|\<elseif\>\|\<endif\>\|\<error\>\|\<warning\>\)/
syn region swiftPreprocFalse
      \ start="^\s*#\<if\>\s\+\<false\>" end="^\s*#\(\<else\>\|\<elseif\>\|\<endif\>\)"

syn match swiftAttribute
      \ /@\<\w\+\>/ skipwhite skipempty nextgroup=swiftType,swiftTypeDefinition

syn keyword swiftTodo MARK TODO FIXME contained

syn match swiftCastOp skipwhite skipempty nextgroup=swiftType,swiftCoreTypes
      \ "\<is\>"
syn match swiftCastOp skipwhite skipempty nextgroup=swiftType,swiftCoreTypes
      \ "\<as\>[!?]\?"

syn match swiftNilOps
      \ "??"

syn region swiftReservedIdentifier oneline
      \ start=/`/ end=/`/

hi def link swiftImport Include
hi def link swiftImportModule Title
hi def link swiftImportComponent Identifier
hi def link swiftKeyword Statement
hi def link swiftCoreTypes Type
hi def link swiftMultiwordKeyword Statement
hi def link swiftTypeDefinition Define
hi def link swiftMultiwordTypeDefinition Define
hi def link swiftType Type
hi def link swiftTypePair Type
hi def link swiftTypeAliasName Identifier
hi def link swiftTypeName Function
hi def link swiftConstraint Special
hi def link swiftFuncDefinition Define
hi def link swiftDefinitionModifier Operator
hi def link swiftInOutKeyword Define
hi def link swiftFuncKeyword Function
hi def link swiftFuncKeywordGeneral Function
hi def link swiftTypeAliasDefinition Define
hi def link swiftVarDefinition Define
hi def link swiftVarName Identifier
hi def link swiftImplicitVarName Identifier
hi def link swiftIdentifierKeyword Identifier
hi def link swiftTypeAliasValue Delimiter
hi def link swiftTypeDeclaration Delimiter
hi def link swiftTypeParameters Delimiter
hi def link swiftBoolean Boolean
hi def link swiftString String
hi def link swiftInterpolation Special
hi def link swiftComment Comment
hi def link swiftLineComment Comment
hi def link swiftDecimal Number
hi def link swiftHex Number
hi def link swiftOct Number
hi def link swiftBin Number
hi def link swiftOperator Function
hi def link swiftChar Character
hi def link swiftLabel Operator
hi def link swiftMutating Statement
hi def link swiftPreproc PreCondit
hi def link swiftPreprocFalse Comment
hi def link swiftAttribute Type
hi def link swiftTodo Todo
hi def link swiftNil Constant
hi def link swiftCastOp Operator
hi def link swiftNilOps Operator
hi def link swiftScope PreProc

let b:current_syntax = "swift"

let &cpo = s:keepcpo
unlet s:keepcpo
