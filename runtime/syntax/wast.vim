" Vim syntax file
" Language:     WebAssembly
" Maintainer:   rhysd <lin90162@yahoo.co.jp>
" Last Change:  Aug 7, 2023
" For bugs, patches and license go to https://github.com/rhysd/vim-wasm

if exists("b:current_syntax")
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn cluster wastNotTop contains=wastModule,wastInstWithType,wastInstGetSet,wastInstGeneral,wastParamInst,wastControlInst,wastSimdInst,wastString,wastNamedVar,wastUnnamedVar,wastFloat,wastNumber,wastComment,wastList,wastType

" Instructions
" https://webassembly.github.io/spec/core/text/instructions.html
" Note: memarg (align=,offset=) can be added to memory instructions
syn match   wastInstWithType  "\%((\s*\)\@<=\<\%(i32\|i64\|f32\|f64\|memory\)\.[[:alnum:]_]\+\%(/\%(i32\|i64\|f32\|f64\)\)\=\>\%(\s\+\%(align\|offset\)=\)\=" contained display
syn match   wastInstGeneral   "\%((\s*\)\@<=\<[[:alnum:]_]\+\>" contained display
syn match   wastInstGetSet    "\%((\s*\)\@<=\<\%(local\|global\)\.\%(get\|set\)\>" contained display
" https://webassembly.github.io/spec/core/text/instructions.html#control-instructions
syn match   wastControlInst   "\%((\s*\)\@<=\<\%(block\|end\|loop\|if\|then\|else\|unreachable\|nop\|br\|br_if\|br_table\|return\|call\|call_indirect\)\>" contained display
" https://webassembly.github.io/spec/core/text/instructions.html#parametric-instructions
syn match   wastParamInst     "\%((\s*\)\@<=\<\%(drop\|select\)\>" contained display
" SIMD instructions
" https://webassembly.github.io/simd/core/text/instructions.html#simd-instructions
syn match   wastSimdInst      "\<\%(v128\|i8x16\|i16x8\|i32x4\|i64x2\|f32x4\|f64x2)\)\.[[:alnum:]_]\+\%(\s\+\%(i8x16\|i16x8\|i32x4\|i64x2\|f32x4\|f64x2\)\)\=\>" contained display

" Identifiers
" https://webassembly.github.io/spec/core/text/values.html#text-id
syn match   wastNamedVar      "$\+[[:alnum:]!#$%&'∗./:=><?@\\^_`~+-]*" contained contains=wastEscapeUtf8
syn match   wastUnnamedVar    "$\+\d\+[[:alnum:]!#$%&'∗./:=><?@\\^_`~+-]\@!" contained display
" Presuming the source text is itself encoded correctly, strings that do not
" contain any uses of hexadecimal byte escapes are always valid names.
" https://webassembly.github.io/spec/core/text/values.html#names
syn match   wastEscapedUtf8   "\\\x\{1,6}" contained containedin=wastNamedVar display

" String literals
" https://webassembly.github.io/spec/core/text/values.html#strings
syn region  wastString        start=+"+ skip=+\\\\\|\\"+ end=+"+ contained contains=wastStringSpecial
syn match   wastStringSpecial "\\\x\x\|\\[tnr'\\\"]\|\\u\x\+" contained containedin=wastString display

" Float literals
" https://webassembly.github.io/spec/core/text/values.html#floating-point
syn match   wastFloat         "\<-\=\d\%(_\=\d\)*\%(\.\d\%(_\=\d\)*\)\=\%([eE][-+]\=\d\%(_\=\d\)*\)\=" display contained
syn match   wastFloat         "\<-\=0x\x\%(_\=\x\)*\%(\.\x\%(_\=\x\)*\)\=\%([pP][-+]\=\d\%(_\=\d\)*\)\=" display contained
syn keyword wastFloat         inf nan contained
syn match   wastFloat         "nan:0x\x\%(_\=\x\)*" display contained

" Integer literals
" https://webassembly.github.io/spec/core/text/values.html#integers
syn match   wastNumber        "\<-\=\d\%(_\=\d\)*\>" display contained
syn match   wastNumber        "\<-\=0x\x\%(_\=\x\)*\>" display contained

" Comments
" https://webassembly.github.io/spec/core/text/lexical.html#comments
syn region  wastComment       start=";;" end="$"
syn region  wastComment       start="(;;\@!" end=";)"

syn region  wastList          matchgroup=wastListDelimiter start="(;\@!" matchgroup=wastListDelimiter end=";\@<!)" contains=@wastNotTop

" Types
" https://webassembly.github.io/spec/core/text/types.html
" Note: `mut` was changed to `const`/`var` at Wasm 2.0
syn keyword wastType          i64 i32 f64 f32 param result funcref func externref extern mut v128 const var contained
syn match   wastType          "\%((\_s*\)\@<=func\%(\_s*[()]\)\@=" display contained

" Modules
" https://webassembly.github.io/spec/core/text/modules.html
syn keyword wastModule        module type export import table memory global data elem contained
syn match   wastModule        "\%((\_s*\)\@<=func\%(\_s\+\$\)\@=" display contained

syn sync maxlines=100

hi def link wastModule        PreProc
hi def link wastListDelimiter Delimiter
hi def link wastInstWithType  Operator
hi def link wastInstGetSet    Operator
hi def link wastInstGeneral   Operator
hi def link wastControlInst   Statement
hi def link wastSimdInst      Operator
hi def link wastParamInst     Conditional
hi def link wastString        String
hi def link wastStringSpecial Special
hi def link wastNamedVar      Identifier
hi def link wastUnnamedVar    PreProc
hi def link wastFloat         Float
hi def link wastNumber        Number
hi def link wastComment       Comment
hi def link wastType          Type
hi def link wastEscapedUtf8   Special

let b:current_syntax = "wast"

let &cpo = s:cpo_save
unlet s:cpo_save
