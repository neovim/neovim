" Vim syntax file
" Language:     WebAssembly
" Maintainer:   rhysd <lin90162@yahoo.co.jp>
" Last Change:  Nov 14, 2023
" For bugs, patches and license go to https://github.com/rhysd/vim-wasm

if exists("b:current_syntax")
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn cluster watNotTop contains=watModule,watInstWithType,watInstGetSet,watInstGeneral,watParamInst,watControlInst,watSimdInst,watString,watNamedVar,watUnnamedVar,watFloat,watNumber,watComment,watList,watType

" Instructions
" https://webassembly.github.io/spec/core/text/instructions.html
" Note: memarg (align=,offset=) can be added to memory instructions
syn match   watInstWithType  "\%((\s*\)\@<=\<\%(i32\|i64\|f32\|f64\|memory\)\.[[:alnum:]_]\+\%(/\%(i32\|i64\|f32\|f64\)\)\=\>\%(\s\+\%(align\|offset\)=\)\=" contained display
syn match   watInstGeneral   "\%((\s*\)\@<=\<[[:alnum:]_]\+\>" contained display
syn match   watInstGetSet    "\%((\s*\)\@<=\<\%(local\|global\)\.\%(get\|set\)\>" contained display
" https://webassembly.github.io/spec/core/text/instructions.html#control-instructions
syn match   watControlInst   "\%((\s*\)\@<=\<\%(block\|end\|loop\|if\|then\|else\|unreachable\|nop\|br\|br_if\|br_table\|return\|call\|call_indirect\)\>" contained display
" https://webassembly.github.io/spec/core/text/instructions.html#parametric-instructions
syn match   watParamInst     "\%((\s*\)\@<=\<\%(drop\|select\)\>" contained display
" SIMD instructions
" https://webassembly.github.io/simd/core/text/instructions.html#simd-instructions
syn match   watSimdInst      "\<\%(v128\|i8x16\|i16x8\|i32x4\|i64x2\|f32x4\|f64x2)\)\.[[:alnum:]_]\+\%(\s\+\%(i8x16\|i16x8\|i32x4\|i64x2\|f32x4\|f64x2\)\)\=\>" contained display

" Identifiers
" https://webassembly.github.io/spec/core/text/values.html#text-id
syn match   watNamedVar      "$\+[[:alnum:]!#$%&'∗./:=><?@\\^_`~+-]*" contained contains=watEscapeUtf8
syn match   watUnnamedVar    "$\+\d\+[[:alnum:]!#$%&'∗./:=><?@\\^_`~+-]\@!" contained display
" Presuming the source text is itself encoded correctly, strings that do not
" contain any uses of hexadecimal byte escapes are always valid names.
" https://webassembly.github.io/spec/core/text/values.html#names
syn match   watEscapedUtf8   "\\\x\{1,6}" contained containedin=watNamedVar display

" String literals
" https://webassembly.github.io/spec/core/text/values.html#strings
syn region  watString        start=+"+ skip=+\\\\\|\\"+ end=+"+ contained contains=watStringSpecial
syn match   watStringSpecial "\\\x\x\|\\[tnr'\\\"]\|\\u\x\+" contained containedin=watString display

" Float literals
" https://webassembly.github.io/spec/core/text/values.html#floating-point
syn match   watFloat         "\<-\=\d\%(_\=\d\)*\%(\.\d\%(_\=\d\)*\)\=\%([eE][-+]\=\d\%(_\=\d\)*\)\=" display contained
syn match   watFloat         "\<-\=0x\x\%(_\=\x\)*\%(\.\x\%(_\=\x\)*\)\=\%([pP][-+]\=\d\%(_\=\d\)*\)\=" display contained
syn keyword watFloat         inf nan contained
syn match   watFloat         "nan:0x\x\%(_\=\x\)*" display contained

" Integer literals
" https://webassembly.github.io/spec/core/text/values.html#integers
syn match   watNumber        "\<-\=\d\%(_\=\d\)*\>" display contained
syn match   watNumber        "\<-\=0x\x\%(_\=\x\)*\>" display contained

" Comments
" https://webassembly.github.io/spec/core/text/lexical.html#comments
syn region  watComment       start=";;" end="$"
syn region  watComment       start="(;;\@!" end=";)"

syn region  watList          matchgroup=watListDelimiter start="(;\@!" matchgroup=watListDelimiter end=";\@<!)" contains=@watNotTop

" Types
" https://webassembly.github.io/spec/core/text/types.html
" Note: `mut` was changed to `const`/`var` at Wasm 2.0
syn keyword watType          i64 i32 f64 f32 param result funcref func externref extern mut v128 const var contained
syn match   watType          "\%((\_s*\)\@<=func\%(\_s*[()]\)\@=" display contained

" Modules
" https://webassembly.github.io/spec/core/text/modules.html
syn keyword watModule        module type export import table memory global data elem contained
syn match   watModule        "\%((\_s*\)\@<=func\%(\_s\+\$\)\@=" display contained

syn sync maxlines=100

hi def link watModule        PreProc
hi def link watListDelimiter Delimiter
hi def link watInstWithType  Operator
hi def link watInstGetSet    Operator
hi def link watInstGeneral   Operator
hi def link watControlInst   Statement
hi def link watSimdInst      Operator
hi def link watParamInst     Conditional
hi def link watString        String
hi def link watStringSpecial Special
hi def link watNamedVar      Identifier
hi def link watUnnamedVar    PreProc
hi def link watFloat         Float
hi def link watNumber        Number
hi def link watComment       Comment
hi def link watType          Type
hi def link watEscapedUtf8   Special

let b:current_syntax = "wat"

let &cpo = s:cpo_save
unlet s:cpo_save
