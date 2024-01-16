" Vim indent plugin file
" Language: Odin
" Maintainer: Maxim Kim <habamax@gmail.com>
" Website: https://github.com/habamax/vim-odin
" Last Change: 2024-01-15
"
" This file has been manually translated from Vim9 script.

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syntax keyword odinKeyword using transmute cast distinct opaque where dynamic
syntax keyword odinKeyword struct enum union const bit_field bit_set
syntax keyword odinKeyword package proc map import export foreign
syntax keyword odinKeyword size_of offset_of type_info_of typeid_of type_of align_of
syntax keyword odinKeyword return defer
syntax keyword odinKeyword or_return or_else
syntax keyword odinKeyword inline no_inline

syntax keyword odinConditional if when else do for switch case continue break
syntax keyword odinType string cstring bool b8 b16 b32 b64 rune any rawptr
syntax keyword odinType f16 f32 f64 f16le f16be f32le f32be f64le f64be
syntax keyword odinType u8 u16 u32 u64 u128 u16le u32le u64le u128le u16be
syntax keyword odinType u32be u64be u128be uint uintptr i8 i16 i32 i64 i128
syntax keyword odinType i16le i32le i64le i128le i16be i32be i64be i128be
syntax keyword odinType int complex complex32 complex64 complex128 matrix typeid
syntax keyword odinType quaternion quaternion64 quaternion128 quaternion256
syntax keyword odinBool true false
syntax keyword odinNull nil
syntax match odinUninitialized '\s\+---\(\s\|$\)'

syntax keyword odinOperator in notin not_in
syntax match odinOperator "?" display
syntax match odinOperator "->" display

syntax match odinTodo "TODO" contained
syntax match odinTodo "XXX" contained
syntax match odinTodo "FIXME" contained
syntax match odinTodo "HACK" contained

syntax region odinRawString start=+`+ end=+`+
syntax region odinChar start=+'+ skip=+\\\\\|\\'+ end=+'+
syntax region odinString start=+"+ skip=+\\\\\|\\'+ end=+"+ contains=odinEscape
syntax match odinEscape display contained /\\\([nrt\\'"]\|x\x\{2}\)/

syntax match odinProcedure "\v<\w*>(\s*::\s*proc)@="

syntax match odinAttribute "@\ze\<\w\+\>" display
syntax region odinAttribute
      \ matchgroup=odinAttribute
      \ start="@\ze(" end="\ze)"
      \ transparent oneline

syntax match odinInteger "\-\?\<\d\+\>" display
syntax match odinFloat "\-\?\<[0-9][0-9_]*\%(\.[0-9][0-9_]*\)\%([eE][+-]\=[0-9_]\+\)\=" display
syntax match odinHex "\<0[xX][0-9A-Fa-f]\+\>" display
syntax match odinDoz "\<0[zZ][0-9a-bA-B]\+\>" display
syntax match odinOct "\<0[oO][0-7]\+\>" display
syntax match odinBin "\<0[bB][01]\+\>" display

syntax match odinAddressOf "&" display
syntax match odinDeref "\^" display

syntax match odinMacro "#\<\w\+\>" display

syntax match odinTemplate "$\<\w\+\>"

syntax region odinLineComment start=/\/\// end=/$/  contains=@Spell,odinTodo
syntax region odinBlockComment start=/\/\*/ end=/\*\// contains=@Spell,odinTodo,odinBlockComment
syn sync ccomment odinBlockComment

highlight def link odinKeyword Statement
highlight def link odinConditional Conditional
highlight def link odinOperator Operator

highlight def link odinString String
highlight def link odinRawString String
highlight def link odinChar Character
highlight def link odinEscape Special

highlight def link odinProcedure Function

highlight def link odinMacro PreProc

highlight def link odinLineComment Comment
highlight def link odinBlockComment Comment

highlight def link odinTodo Todo

highlight def link odinAttribute Statement
highlight def link odinType Type
highlight def link odinBool Boolean
highlight def link odinNull Constant
highlight def link odinUninitialized Constant
highlight def link odinInteger Number
highlight def link odinFloat Float
highlight def link odinHex Number
highlight def link odinOct Number
highlight def link odinBin Number
highlight def link odinDoz Number

let b:current_syntax = "odin"

let &cpo = s:cpo_save
unlet s:cpo_save
