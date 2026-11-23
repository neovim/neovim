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
" Last Change: 2026 Nov 22
"
" Vim maintainer: Emir SARI <bitigchi@me.com>

if exists("b:current_syntax")
    finish
endif

let s:keepcpo = &cpo
set cpo&vim

" ---- Keywords ----

syn keyword swiftKeyword
      \ await
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
      \ unsafe
      \ while
syn match swiftMultiwordKeyword
      \ "indirect case"

" `copy`/`consume` are only the explicit-copy/move operators (`copy x`,
" `consume x`) when immediately followed by an identifier/self/$ident on
" the same line; otherwise they are ordinary identifiers (`copy()`,
" `let copy = ...`, `x.copy`, and likewise for `consume`).
syn match swiftKeyword /\<copy\>\ze\s\+[A-Za-z_$]/
syn match swiftKeyword /\<consume\>\ze\s\+[A-Za-z_$]/

syn keyword swiftIdentifierKeyword
      \ Self
      \ metatype
      \ self
      \ super

syn keyword swiftScope
      \ autoreleasepool

syn keyword swiftLabel
      \ get
      \ set
      \ didSet
      \ willSet

" ---- Modifiers & specifiers ----

" nonisolated(unsafe), nonisolated(nonsending), unowned(safe), unowned(unsafe)
syn keyword swiftModifierArgument contained
      \ nonsending
      \ safe
      \ unsafe
syn region swiftModifierArguments contained transparent
      \ matchgroup=Delimiter start=/(/ end=/)/
      \ contains=swiftModifierArgument
syn keyword swiftDefinitionModifier skipwhite skipempty nextgroup=swiftModifierArguments
      \ nonisolated
      \ unowned

syn keyword swiftDefinitionModifier
      \ async
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
      \ package
      \ private
      \ public
      \ reasync
      \ required
      \ rethrows
      \ static
      \ throws
      \ weak

syn keyword swiftTypeSpecifier contained skipwhite skipempty nextgroup=@swiftTypeContext
      \ borrowing
      \ consuming
      \ inout
      \ isolated

syn keyword swiftConcurrencySpecifier contained skipwhite skipempty nextgroup=@swiftTypeContext
      \ sending

syn keyword swiftFuncAttribute skipwhite skipempty nextgroup=swiftFuncDefinition
      \ borrowing
      \ consuming
      \ mutating

" ---- Declarations ----

syn keyword swiftImport skipwhite skipempty nextgroup=swiftImportModule
      \ import
syn match swiftImportModule contained nextgroup=swiftImportComponent
      \ /\<[A-Za-z_][A-Za-z_0-9]*\>/
syn match swiftImportComponent contained nextgroup=swiftImportComponent
      \ /\.\<[A-Za-z_][A-Za-z_0-9]*\>/

syn keyword swiftFuncKeywordGeneral skipwhite skipempty nextgroup=swiftTypeParameters
      \ init

syn keyword swiftFuncKeyword
      \ deinit
      \ subscript

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
syn match swiftMultiwordTypeDefinition skipwhite skipempty nextgroup=swiftTypeName
      \ "indirect enum"

syn keyword swiftTypeAliasDefinition skipwhite skipempty nextgroup=swiftTypeAliasName
      \ associatedtype
      \ typealias

" let (a, b, c) = ... (tuple destructuring pattern). A region, like the
" `<...>` generic-parameter clause, so nested tuples and any number of
" names all get swiftVarName treatment, the same as a single `let x = ...`.
syn region swiftVarNamePattern contained contains=swiftVarNamePattern,swiftVarName,swiftParamDelim
      \ matchgroup=Delimiter start=/(/ end=/)/

syn keyword swiftVarDefinition skipwhite skipempty nextgroup=swiftVarName,swiftVarNamePattern
      \ let
      \ var

" ---- Types ----

syn keyword swiftCoreTypes
      \ Any
      \ AnyObject

" Foo<Bar> in expression position, e.g. `MemoryLayout<any P>.size`. Must
" precede the contained matches below so a declaration name like `Foo` in
" `struct Foo<T>` still wins there, not this rule.
syn match swiftType skipwhite skipempty nextgroup=swiftTypeParameters
      \ /\<[A-Z][A-Za-z_0-9]*\>\ze</

" Everything that can start a type; keeps the triggers below in sync.
syn cluster swiftTypeContext contains=swiftTypeSpecifier,swiftConcurrencySpecifier,swiftExistentialType,swiftOpaqueType

syn keyword swiftExistentialType contained skipwhite skipempty nextgroup=@swiftTypeContext
      \ any

syn keyword swiftOpaqueType contained skipwhite skipempty nextgroup=@swiftTypeContext
      \ some

syn match swiftTypeAliasName contained skipwhite skipempty nextgroup=swiftTypeAliasValue
      \ /\<[A-Za-z_][A-Za-z_0-9]*\>/
syn match swiftTypeName contained skipwhite skipempty nextgroup=swiftTypeParameters
      \ /\<[A-Za-z_][A-Za-z_0-9\.]*\>/
syn match swiftVarName contained skipwhite skipempty nextgroup=swiftTypeDeclaration
      \ /\<[A-Za-z_][A-Za-z_0-9]*\>/
syn match swiftImplicitVarName
      \ /\$\<[A-Za-z_0-9]\+\>/

" Codable & Equatable (protocol composition). contained, so it only ever
" chains off an already-recognized type; it can't be confused with the
" bitwise-and operator in ordinary expressions.
syn match swiftProtocolComposition contained skipwhite skipempty nextgroup=@swiftTypeContext
      \ /&/

" A, B in `class X: A, B` (inheritance/conformance list). The lookahead
" requires the next identifier not be followed by `:`, so a parameter
" name or labeled tuple element (`f(a: Int, b: String)`) is not mistaken
" for another type.
syn match swiftTypeListComma contained skipwhite skipempty nextgroup=@swiftTypeContext
      \ /,\ze\s*[A-Za-z_][A-Za-z_0-9]*\%(\s*:\)\@!/

" `, subject ==` continues a same-type requirement after a comma; the
" lookahead keeps ordinary tuple/parameter-list commas unaffected.
syn match swiftWhereConstraintComma contained skipwhite skipempty nextgroup=swiftWhereConstraintSubject
      \ /,\ze\s*[A-Za-z_][A-Za-z_0-9.]*\s*==/

" TypeName[Optionality]?
syn match swiftType contained skipwhite skipempty nextgroup=swiftTypeParameters,swiftProtocolComposition,swiftTypeListComma,swiftWhereConstraintComma
      \ /\<[A-Za-z_][A-Za-z_0-9\.]*\>[!?]\?/
" [Type:Type] (dictionary) or [Type] (array)
syn region swiftType contained contains=swiftTypePair,@swiftTypeContext
      \ matchgroup=Delimiter start=/\[/ end=/\]/
syn match swiftTypePair contained skipwhite skipempty nextgroup=swiftTypeParameters,swiftTypeDeclaration
      \ /\<[A-Za-z_][A-Za-z_0-9\.]*\>[!?]\?/
" (Type[, Type]) (tuple)
" FIXME: we should be able to use skip="," and drop swiftParamDelim
syn region swiftType contained contains=swiftParamDelim,@swiftTypeContext
      \ matchgroup=Delimiter start="[^@]\?(" end=")" matchgroup=NONE skip=","
syn match swiftParamDelim contained
      \ /,/
" <Generic Clause> (generics)
syn region swiftTypeParameters contained contains=swiftVarName,swiftConstraint,swiftOpaqueType,swiftExistentialType
      \ matchgroup=Delimiter start="<" end=">" matchgroup=NONE skip=","
syn keyword swiftConstraint contained
      \ where

" Added once swiftType itself is fully defined above.
syn cluster swiftTypeContext add=swiftType

syn match swiftTypeAliasValue skipwhite skipempty nextgroup=@swiftTypeContext
      \ /=/
syn match swiftTypeDeclaration skipwhite skipempty nextgroup=@swiftTypeContext
      \ /:/
syn match swiftTypeDeclaration skipwhite skipempty nextgroup=@swiftTypeContext
      \ /->/

syn match swiftCastOp skipwhite skipempty nextgroup=@swiftTypeContext,swiftCoreTypes
      \ "\<is\>"
syn match swiftCastOp skipwhite skipempty nextgroup=@swiftTypeContext,swiftCoreTypes
      \ "\<as\>[!?]\?"

" where T == Int (same-type requirement); `:` conformance already works
" without this, since swiftTypeDeclaration is not `contained`.
syn match swiftWhereSameType contained skipwhite skipempty nextgroup=@swiftTypeContext
      \ /==/
syn match swiftWhereConstraintSubject contained skipwhite skipempty nextgroup=swiftWhereSameType
      \ /\<[A-Za-z_][A-Za-z_0-9]*\>\%(\.[A-Za-z_][A-Za-z_0-9]*\)*/
syn keyword swiftKeyword skipwhite skipempty nextgroup=swiftWhereConstraintSubject
      \ where

" ---- Literals ----

syn keyword swiftBoolean
      \ false
      \ true

syn keyword swiftNil
      \ nil

syn match swiftDecimal
      \ /[+\-]\?\<\([0-9][0-9_]*\)\([.][0-9_]*\)\?\([eE][+\-]\?[0-9][0-9_]*\)\?\>/
syn match swiftHex
      \ /[+\-]\?\<0x[0-9A-Fa-f][0-9A-Fa-f_]*\(\([.][0-9A-Fa-f_]*\)\?[pP][+\-]\?[0-9][0-9_]*\)\?\>/
syn match swiftOct
      \ /[+\-]\?\<0o[0-7][0-7_]*\>/
syn match swiftBin
      \ /[+\-]\?\<0b[01][01_]*\>/

syn match swiftChar
      \ /'\([^'\\]\|\\\(["'tnr0\\]\|x[0-9a-fA-F]\{2}\|u[0-9a-fA-F]\{4}\|U[0-9a-fA-F]\{8}\)\)'/

syn region swiftString contains=swiftInterpolationRegion
      \ start=/"/ skip=/\\\\\|\\"/ end=/"/
" """..."""  Must be defined after the single-line swiftString above so
" it wins when both could start at the same `"`, per :syn-priority (the
" item defined last has priority for matches starting at the same spot).
syn region swiftString contains=swiftInterpolationRegion
      \ start=/"""/ skip=/\\\\\|\\"/ end=/"""/
syn region swiftInterpolationRegion contained contains=TOP
      \ matchgroup=swiftInterpolation start=/\\(/ end=/)/

" #"..."#  Raw string: no escape processing at all except `\#(` for
" interpolation. Only the single-`#` delimiter is handled; `##"..."##`
" and higher would need matching delimiter counts on both ends, which a
" plain start/end pair cannot enforce.
syn region swiftString contains=swiftInterpolationRegion
      \ start=/#"/ end=/"#/
syn region swiftInterpolationRegion contained contains=TOP
      \ matchgroup=swiftInterpolation start=/\\#(/ end=/)/

syn match swiftTupleIndexNumber contains=swiftDecimal
      \ /\.[0-9]\+/

" \Type.path or \.path (key path literal). The whole path is a single
" token, since a plain regex cannot distinguish the leading type name
" from the member names that follow it.
syn match swiftKeyPath
      \ /\\\%([A-Za-z_][A-Za-z_0-9]*\)\?\%(\.[A-Za-z_][A-Za-z_0-9]*[?!]\?\)\+/
syn match swiftDecimal contained
      \ /[0-9]\+/

" ---- Case labels ----

syn match swiftKeyword
      \ /\<case\>/
syn region swiftCaseLabelRegion
      \ matchgroup=swiftKeyword start=/\<case\>/ matchgroup=Delimiter end=/:/ oneline contains=TOP
syn region swiftDefaultLabelRegion
      \ matchgroup=swiftKeyword start=/\<default\>/ matchgroup=Delimiter end=/:/ oneline

" ---- Operators & delimiters ----

syn region swiftParenthesisRegion contains=TOP
      \ matchgroup=NONE start=/(/ end=/)/

syn match swiftOperator skipwhite skipempty nextgroup=swiftTypeParameters
      \ "\.\@<!\.\.\.\@!\|[/=\-+*%<>!&|^~]\@<!\(/[/*]\@![/=\-+*%<>!&|^~]*\|*/\@![/=\-+*%<>!&|^~]*\|->\@![/=\-+*%<>!&|^~]*\|[=+%<>!&|^~][/=\-+*%<>!&|^~]*\)"
syn match swiftOperator skipwhite skipempty nextgroup=swiftTypeParameters
      \ "\.\.[<.]"

syn match swiftNilOps
      \ "??"

" ---- Attributes ----

syn match swiftAttribute
      \ /@\<\w\+\>/ skipwhite skipempty nextgroup=swiftAttribute,swiftDefinitionModifier,swiftImport,swiftType,swiftTypeAliasDefinition,swiftTypeDefinition

" @convention(c) (Params) -> Return. Unlike a plain @attribute, the
" parens here are the attribute's own argument (the calling convention),
" not the type it applies to; that function type follows once the
" parens close, and @swiftTypeContext picks it up from there. Defined
" after the plain @attribute match above so it wins for this one name.
syn keyword swiftConventionArgument contained
      \ block
      \ c
      \ swift
      \ thin
syn region swiftAttribute skipwhite skipempty nextgroup=@swiftTypeContext contains=swiftConventionArgument
      \ matchgroup=swiftAttribute start=/@convention(/ end=/)/

" ---- Preprocessor & macros ----

" This is a superset of the Preproc macros below, so it must come FIRST
syn match swiftFreestandingMacro
      \ /#\<[A-Za-z_][A-Za-z_0-9]*\>/
syn match swiftPreproc
      \ /#\(\<column\>\|\<dsohandle\>\|\<file\>\|\<line\>\|\<function\>\)/
syn match swiftPreproc
      \ /^\s*#\(\<if\>\|\<else\>\|\<elseif\>\|\<endif\>\|\<error\>\|\<warning\>\)/
syn region swiftPreprocFalse
      \ start="^\s*#\<if\>\s\+\<false\>" end="^\s*#\(\<else\>\|\<elseif\>\|\<endif\>\)"

" ---- Comments ----

syn region swiftComment contains=swiftComment,swiftTodo
      \ start="/\*" end="\*/"
syn region swiftLineComment contains=swiftTodo
      \ start="//" end="$"
syn keyword swiftTodo MARK TODO FIXME contained

" ---- Misc ----

syn region swiftReservedIdentifier oneline
      \ start=/`/ end=/`/

" ---- Highlighting links ----

hi def link swiftKeyword Statement
hi def link swiftMultiwordKeyword Statement
hi def link swiftIdentifierKeyword Identifier
hi def link swiftScope Statement
hi def link swiftLabel Label

hi def link swiftModifierArgument Special
hi def link swiftDefinitionModifier Keyword
hi def link swiftTypeSpecifier Keyword
hi def link swiftConcurrencySpecifier Keyword
hi def link swiftFuncAttribute Keyword

hi def link swiftImport Include
hi def link swiftImportModule Title
hi def link swiftImportComponent Identifier
hi def link swiftFuncKeywordGeneral Function
hi def link swiftFuncKeyword Function
hi def link swiftFuncDefinition Define
hi def link swiftTypeDefinition Structure
hi def link swiftMultiwordTypeDefinition Structure
hi def link swiftTypeAliasDefinition Typedef
hi def link swiftVarDefinition Define

hi def link swiftCoreTypes Type
hi def link swiftType Type
hi def link swiftTypePair Type
hi def link swiftExistentialType Type
hi def link swiftOpaqueType Type
hi def link swiftTypeAliasName Identifier
hi def link swiftTypeName Function
hi def link swiftVarName Identifier
hi def link swiftImplicitVarName Identifier
hi def link swiftConstraint Special
hi def link swiftTypeAliasValue Delimiter
hi def link swiftTypeDeclaration Delimiter
hi def link swiftTypeParameters Delimiter
hi def link swiftProtocolComposition Operator
hi def link swiftCastOp Operator
hi def link swiftWhereConstraintSubject Identifier
hi def link swiftWhereSameType Operator

hi def link swiftBoolean Boolean
hi def link swiftNil Constant
hi def link swiftDecimal Number
hi def link swiftHex Number
hi def link swiftOct Number
hi def link swiftBin Number
hi def link swiftChar Character
hi def link swiftString String
hi def link swiftInterpolation Special
hi def link swiftKeyPath Special

hi def link swiftOperator Operator
hi def link swiftNilOps Operator

hi def link swiftAttribute PreProc
hi def link swiftConventionArgument Keyword

hi def link swiftPreproc PreCondit
hi def link swiftPreprocFalse Comment
hi def link swiftFreestandingMacro Macro

hi def link swiftComment Comment
hi def link swiftLineComment Comment
hi def link swiftTodo Todo

hi def link swiftReservedIdentifier Identifier

let b:current_syntax = "swift"

let &cpo = s:keepcpo
unlet s:keepcpo
