" This source file is part of the Swift.org open source project
"
" Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
" Licensed under Apache License v2.0 with Runtime Library Exception
"
" See https://swift.org/LICENSE.txt for license information
" See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
"
" Vim syntax file
" Language: sil
"
" Vim maintainer: Emir SARI <bitigchi@me.com>

if exists("b:current_syntax")
    finish
endif

let s:keepcpo = &cpo
set cpo&vim

syn keyword silStage skipwhite nextgroup=silStages
      \ sil_stage
syn keyword silStages
      \ canonical
      \ raw

syn match silIdentifier skipwhite
      \ /@\<[A-Za-z_0-9]\+\>/

syn match silConvention skipwhite
      \ /$\?@convention/
syn region silConvention contained contains=silConventions
      \ start="@convention(" end=")"
syn keyword silConventions
      \ block
      \ c
      \ method
      \ objc_method
      \ thick
      \ thin
      \ witness_method

syn match silFunctionType skipwhite
      \ /@\(\<autoreleased\>\|\<callee_guaranteed\>\|\<callee_owned\>\|\<error\>\|\<guaranteed\>\|\<in\>\|\<in_constant\>\|\<in_guaranteed\>\|\<inout\>\|\<inout_aliasable\>\|\<noescape\>\|\<out\>\|\<owned\>\)/
syn match silMetatypeType skipwhite
      \ /@\(\<thick\>\|\<thin\>\|\<objc\>\)/

" TODO: handle [tail_elems sil-type * sil-operand]
syn region silAttribute contains=silAttributes
      \ start="\[" end="\]"
syn keyword silAttributes contained containedin=silAttribute
      \ abort
      \ deinit
      \ delegatingself
      \ derivedself
      \ derivedselfonly
      \ dynamic
      \ exact
      \ init
      \ modify
      \ mutating
      \ objc
      \ open
      \ read
      \ rootself
      \ stack
      \ static
      \ strict
      \ unknown
      \ unsafe
      \ var

syn keyword swiftImport import skipwhite nextgroup=swiftImportModule
syn match swiftImportModule /\<[A-Za-z_][A-Za-z_0-9]*\>/ contained nextgroup=swiftImportComponent
syn match swiftImportComponent /\.\<[A-Za-z_][A-Za-z_0-9]*\>/ contained nextgroup=swiftImportComponent

syn region swiftComment start="/\*" end="\*/" contains=swiftComment,swiftTodo
syn region swiftLineComment start="//" end="$" contains=swiftTodo

syn match swiftLineComment   /^#!.*/
syn match swiftTypeName  /\<[A-Z][a-zA-Z_0-9]*\>/
syn match swiftDecimal /\<[-]\?[0-9]\+\>/
syn match swiftDecimal /\<[-+]\?[0-9]\+\>/

syn match swiftTypeName /\$\*\<\?[A-Z][a-zA-Z0-9_]*\>/
syn match swiftVarName /%\<[A-z[a-z_0-9]\+\(#[0-9]\+\)\?\>/

syn keyword swiftKeyword break case continue default do else for if in static switch repeat return where while skipwhite

syn keyword swiftKeyword sil internal thunk skipwhite
syn keyword swiftKeyword public hidden private shared public_external hidden_external skipwhite
syn keyword swiftKeyword getter setter allocator initializer enumelt destroyer globalaccessor objc skipwhite
syn keyword swiftKeyword alloc_global alloc_stack alloc_ref alloc_ref_dynamic alloc_box alloc_existential_box alloc_value_buffer dealloc_stack dealloc_box dealloc_existential_box dealloc_ref dealloc_partial_ref dealloc_value_buffer skipwhite
syn keyword swiftKeyword debug_value debug_value_addr skipwhite
syn keyword swiftKeyword load load_unowned store assign mark_uninitialized mark_function_escape copy_addr destroy_addr index_addr index_raw_pointer bind_memory to skipwhite
syn keyword swiftKeyword strong_retain strong_release strong_retain_unowned ref_to_unowned unowned_to_ref unowned_retain unowned_release load_weak store_unowned store_weak fix_lifetime autorelease_value set_deallocating is_unique is_escaping_closure skipwhite
syn keyword swiftKeyword function_ref integer_literal float_literal string_literal global_addr skipwhite
syn keyword swiftKeyword class_method super_method witness_method objc_method objc_super_method skipwhite
syn keyword swiftKeyword partial_apply builtin skipwhite
syn keyword swiftApplyKeyword apply try_apply skipwhite
syn keyword swiftKeyword metatype value_metatype existential_metatype skipwhite
syn keyword swiftKeyword retain_value release_value retain_value_addr release_value_addr tuple tuple_extract tuple_element_addr struct struct_extract struct_element_addr ref_element_addr skipwhite
syn keyword swiftKeyword init_enum_data_addr unchecked_enum_data unchecked_take_enum_data_addr inject_enum_addr skipwhite
syn keyword swiftKeyword init_existential_addr init_existential_value init_existential_metatype deinit_existential_addr deinit_existential_value open_existential_addr open_existential_box open_existential_box_value open_existential_metatype init_existential_ref open_existential_ref open_existential_value skipwhite
syn keyword swiftKeyword upcast address_to_pointer pointer_to_address pointer_to_thin_function unchecked_addr_cast unchecked_ref_cast unchecked_ref_cast_addr ref_to_raw_pointer ref_to_bridge_object ref_to_unmanaged unmanaged_to_ref raw_pointer_to_ref skipwhite
syn keyword swiftKeyword convert_function thick_to_objc_metatype thin_function_to_pointer objc_to_thick_metatype thin_to_thick_function unchecked_ref_bit_cast unchecked_trivial_bit_cast bridge_object_to_ref bridge_object_to_word unchecked_bitwise_cast skipwhite
syn keyword swiftKeyword objc_existential_metatype_to_object objc_metatype_to_object objc_protocol skipwhite
syn keyword swiftKeyword unconditional_checked_cast unconditional_checked_cast_addr unconditional_checked_cast_value skipwhite
syn keyword swiftKeyword cond_fail skipwhite
syn keyword swiftKeyword unreachable return throw br cond_br switch_value select_enum select_enum_addr select_value switch_enum switch_enum_addr dynamic_method_br checked_cast_br checked_cast_value_br checked_cast_addr_br skipwhite
syn keyword swiftKeyword project_box project_existential_box project_value_buffer project_block_storage init_block_storage_header copy_block mark_dependence skipwhite

syn keyword swiftTypeDefinition class extension protocol struct typealias enum skipwhite nextgroup=swiftTypeName
syn region swiftTypeAttributes start="\[" end="\]" skipwhite contained nextgroup=swiftTypeName
syn match swiftTypeName /\<[A-Za-z_][A-Za-z_0-9\.]*\>/ contained nextgroup=swiftTypeParameters

syn region swiftTypeParameters start="<" end=">" skipwhite contained

syn keyword swiftFuncDefinition func skipwhite nextgroup=swiftFuncAttributes,swiftFuncName,swiftOperator
syn region swiftFuncAttributes start="\[" end="\]" skipwhite contained nextgroup=swiftFuncName,swiftOperator
syn match swiftFuncName /\<[A-Za-z_][A-Za-z_0-9]*\>/ skipwhite contained nextgroup=swiftTypeParameters
syn keyword swiftFuncKeyword subscript init destructor nextgroup=swiftTypeParameters

syn keyword swiftVarDefinition var skipwhite nextgroup=swiftVarName
syn keyword swiftVarDefinition let skipwhite nextgroup=swiftVarName
syn match swiftVarName /\<[A-Za-z_][A-Za-z_0-9]*\>/ skipwhite contained

syn keyword swiftDefinitionModifier static

syn match swiftImplicitVarName /\$\<[A-Za-z_0-9]\+\>/

hi def link swiftImport Include
hi def link swiftImportModule Title
hi def link swiftImportComponent Identifier
hi def link swiftApplyKeyword Statement
hi def link swiftKeyword Statement
hi def link swiftTypeDefinition Define
hi def link swiftTypeName Type
hi def link swiftTypeParameters Special
hi def link swiftTypeAttributes PreProc
hi def link swiftFuncDefinition Define
hi def link swiftDefinitionModifier Define
hi def link swiftFuncName Function
hi def link swiftFuncAttributes PreProc
hi def link swiftFuncKeyword Function
hi def link swiftVarDefinition Define
hi def link swiftVarName Identifier
hi def link swiftImplicitVarName Identifier
hi def link swiftIdentifierKeyword Identifier
hi def link swiftTypeDeclaration Delimiter
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
hi def link swiftLabel Label
hi def link swiftNew Operator

hi def link silStage Special
hi def link silStages Type
hi def link silConvention Special
hi def link silConventionParameter Special
hi def link silConventions Type
hi def link silIdentifier Identifier
hi def link silFunctionType Special
hi def link silMetatypeType Special
hi def link silAttribute PreProc

let b:current_syntax = "sil"

let &cpo = s:keepcpo
unlet s:keepcpo
