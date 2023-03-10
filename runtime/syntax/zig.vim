" Vim syntax file
" Language: Zig
" Upstream: https://github.com/ziglang/zig.vim

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let s:zig_syntax_keywords = {
    \   'zigBoolean': ["true"
    \ ,                "false"]
    \ , 'zigNull': ["null"]
    \ , 'zigType': ["bool"
    \ ,             "f16"
    \ ,             "f32"
    \ ,             "f64"
    \ ,             "f80"
    \ ,             "f128"
    \ ,             "void"
    \ ,             "type"
    \ ,             "anytype"
    \ ,             "anyerror"
    \ ,             "anyframe"
    \ ,             "volatile"
    \ ,             "linksection"
    \ ,             "noreturn"
    \ ,             "allowzero"
    \ ,             "i0"
    \ ,             "u0"
    \ ,             "isize"
    \ ,             "usize"
    \ ,             "comptime_int"
    \ ,             "comptime_float"
    \ ,             "c_short"
    \ ,             "c_ushort"
    \ ,             "c_int"
    \ ,             "c_uint"
    \ ,             "c_long"
    \ ,             "c_ulong"
    \ ,             "c_longlong"
    \ ,             "c_ulonglong"
    \ ,             "c_longdouble"
    \ ,             "anyopaque"]
    \ , 'zigConstant': ["undefined"
    \ ,                 "unreachable"]
    \ , 'zigConditional': ["if"
    \ ,                    "else"
    \ ,                    "switch"]
    \ , 'zigRepeat': ["while"
    \ ,               "for"]
    \ , 'zigComparatorWord': ["and"
    \ ,                       "or"
    \ ,                       "orelse"]
    \ , 'zigStructure': ["struct"
    \ ,                  "enum"
    \ ,                  "union"
    \ ,                  "error"
    \ ,                  "packed"
    \ ,                  "opaque"]
    \ , 'zigException': ["error"]
    \ , 'zigVarDecl': ["var"
    \ ,                "const"
    \ ,                "comptime"
    \ ,                "threadlocal"]
    \ , 'zigDummyVariable': ["_"]
    \ , 'zigKeyword': ["fn"
    \ ,                "try"
    \ ,                "test"
    \ ,                "pub"
    \ ,                "usingnamespace"]
    \ , 'zigExecution': ["return"
    \ ,                  "break"
    \ ,                  "continue"]
    \ , 'zigMacro': ["defer"
    \ ,              "errdefer"
    \ ,              "async"
    \ ,              "nosuspend"
    \ ,              "await"
    \ ,              "suspend"
    \ ,              "resume"
    \ ,              "export"
    \ ,              "extern"]
    \ , 'zigPreProc': ["catch"
    \ ,                "inline"
    \ ,                "noinline"
    \ ,                "asm"
    \ ,                "callconv"
    \ ,                "noalias"]
    \ , 'zigBuiltinFn': ["align"
    \ ,                  "@addWithOverflow"
    \ ,                  "@as"
    \ ,                  "@atomicLoad"
    \ ,                  "@atomicStore"
    \ ,                  "@bitCast"
    \ ,                  "@breakpoint"
    \ ,                  "@alignCast"
    \ ,                  "@alignOf"
    \ ,                  "@cDefine"
    \ ,                  "@cImport"
    \ ,                  "@cInclude"
    \ ,                  "@cUndef"
    \ ,                  "@clz"
    \ ,                  "@cmpxchgWeak"
    \ ,                  "@cmpxchgStrong"
    \ ,                  "@compileError"
    \ ,                  "@compileLog"
    \ ,                  "@ctz"
    \ ,                  "@popCount"
    \ ,                  "@divExact"
    \ ,                  "@divFloor"
    \ ,                  "@divTrunc"
    \ ,                  "@embedFile"
    \ ,                  "@export"
    \ ,                  "@extern"
    \ ,                  "@tagName"
    \ ,                  "@TagType"
    \ ,                  "@errorName"
    \ ,                  "@call"
    \ ,                  "@errorReturnTrace"
    \ ,                  "@fence"
    \ ,                  "@fieldParentPtr"
    \ ,                  "@field"
    \ ,                  "@unionInit"
    \ ,                  "@frameAddress"
    \ ,                  "@import"
    \ ,                  "@newStackCall"
    \ ,                  "@asyncCall"
    \ ,                  "@intToPtr"
    \ ,                  "@max"
    \ ,                  "@min"
    \ ,                  "@memcpy"
    \ ,                  "@memset"
    \ ,                  "@mod"
    \ ,                  "@mulAdd"
    \ ,                  "@mulWithOverflow"
    \ ,                  "@splat"
    \ ,                  "@src"
    \ ,                  "@bitOffsetOf"
    \ ,                  "@byteOffsetOf"
    \ ,                  "@offsetOf"
    \ ,                  "@OpaqueType"
    \ ,                  "@panic"
    \ ,                  "@prefetch"
    \ ,                  "@ptrCast"
    \ ,                  "@ptrToInt"
    \ ,                  "@rem"
    \ ,                  "@returnAddress"
    \ ,                  "@setCold"
    \ ,                  "@Type"
    \ ,                  "@shuffle"
    \ ,                  "@reduce"
    \ ,                  "@select"
    \ ,                  "@setRuntimeSafety"
    \ ,                  "@setEvalBranchQuota"
    \ ,                  "@setFloatMode"
    \ ,                  "@shlExact"
    \ ,                  "@This"
    \ ,                  "@hasDecl"
    \ ,                  "@hasField"
    \ ,                  "@shlWithOverflow"
    \ ,                  "@shrExact"
    \ ,                  "@sizeOf"
    \ ,                  "@bitSizeOf"
    \ ,                  "@sqrt"
    \ ,                  "@byteSwap"
    \ ,                  "@subWithOverflow"
    \ ,                  "@intCast"
    \ ,                  "@floatCast"
    \ ,                  "@intToFloat"
    \ ,                  "@floatToInt"
    \ ,                  "@boolToInt"
    \ ,                  "@errSetCast"
    \ ,                  "@truncate"
    \ ,                  "@typeInfo"
    \ ,                  "@typeName"
    \ ,                  "@TypeOf"
    \ ,                  "@atomicRmw"
    \ ,                  "@intToError"
    \ ,                  "@errorToInt"
    \ ,                  "@intToEnum"
    \ ,                  "@enumToInt"
    \ ,                  "@setAlignStack"
    \ ,                  "@frame"
    \ ,                  "@Frame"
    \ ,                  "@frameSize"
    \ ,                  "@bitReverse"
    \ ,                  "@Vector"
    \ ,                  "@sin"
    \ ,                  "@cos"
    \ ,                  "@tan"
    \ ,                  "@exp"
    \ ,                  "@exp2"
    \ ,                  "@log"
    \ ,                  "@log2"
    \ ,                  "@log10"
    \ ,                  "@fabs"
    \ ,                  "@floor"
    \ ,                  "@ceil"
    \ ,                  "@trunc"
    \ ,                  "@wasmMemorySize"
    \ ,                  "@wasmMemoryGrow"
    \ ,                  "@round"]
    \ }

function! s:syntax_keyword(dict)
  for key in keys(a:dict)
    execute 'syntax keyword' key join(a:dict[key], ' ')
  endfor
endfunction

call s:syntax_keyword(s:zig_syntax_keywords)

syntax match zigType "\v<[iu][1-9]\d*>"
syntax match zigOperator display "\V\[-+/*=^&?|!><%~]"
syntax match zigArrowCharacter display "\V->"

"                                     12_34  (. but not ..)? (12_34)?     (exponent  12_34)?
syntax match zigDecNumber display   "\v<\d%(_?\d)*%(\.\.@!)?%(\d%(_?\d)*)?%([eE][+-]?\d%(_?\d)*)?"
syntax match zigHexNumber display "\v<0x\x%(_?\x)*%(\.\.@!)?%(\x%(_?\x)*)?%([pP][+-]?\d%(_?\d)*)?"
syntax match zigOctNumber display "\v<0o\o%(_?\o)*"
syntax match zigBinNumber display "\v<0b[01]%(_?[01])*"

syntax match zigCharacterInvalid display contained /b\?'\zs[\n\r\t']\ze'/
syntax match zigCharacterInvalidUnicode display contained /b'\zs[^[:cntrl:][:graph:][:alnum:][:space:]]\ze'/
syntax match zigCharacter /b'\([^\\]\|\\\(.\|x\x\{2}\)\)'/ contains=zigEscape,zigEscapeError,zigCharacterInvalid,zigCharacterInvalidUnicode
syntax match zigCharacter /'\([^\\]\|\\\(.\|x\x\{2}\|u\x\{4}\|U\x\{6}\)\)'/ contains=zigEscape,zigEscapeUnicode,zigEscapeError,zigCharacterInvalid

syntax region zigBlock start="{" end="}" transparent fold

syntax region zigCommentLine start="//" end="$" contains=zigTodo,@Spell
syntax region zigCommentLineDoc start="//[/!]/\@!" end="$" contains=zigTodo,@Spell

syntax match zigMultilineStringPrefix /c\?\\\\/ contained containedin=zigMultilineString
syntax region zigMultilineString matchgroup=zigMultilineStringDelimiter start="c\?\\\\" end="$" contains=zigMultilineStringPrefix display

syntax keyword zigTodo contained TODO

syntax region zigString matchgroup=zigStringDelimiter start=+c\?"+ skip=+\\\\\|\\"+ end=+"+ oneline contains=zigEscape,zigEscapeUnicode,zigEscapeError,@Spell
syntax match zigEscapeError   display contained /\\./
syntax match zigEscape        display contained /\\\([nrt\\'"]\|x\x\{2}\)/
syntax match zigEscapeUnicode display contained /\\\(u\x\{4}\|U\x\{6}\)/

highlight default link zigDecNumber zigNumber
highlight default link zigHexNumber zigNumber
highlight default link zigOctNumber zigNumber
highlight default link zigBinNumber zigNumber

highlight default link zigBuiltinFn Statement
highlight default link zigKeyword Keyword
highlight default link zigType Type
highlight default link zigCommentLine Comment
highlight default link zigCommentLineDoc Comment
highlight default link zigDummyVariable Comment
highlight default link zigTodo Todo
highlight default link zigString String
highlight default link zigStringDelimiter String
highlight default link zigMultilineString String
highlight default link zigMultilineStringContent String
highlight default link zigMultilineStringPrefix String
highlight default link zigMultilineStringDelimiter Delimiter
highlight default link zigCharacterInvalid Error
highlight default link zigCharacterInvalidUnicode zigCharacterInvalid
highlight default link zigCharacter Character
highlight default link zigEscape Special
highlight default link zigEscapeUnicode zigEscape
highlight default link zigEscapeError Error
highlight default link zigBoolean Boolean
highlight default link zigNull Boolean
highlight default link zigConstant Constant
highlight default link zigNumber Number
highlight default link zigArrowCharacter zigOperator
highlight default link zigOperator Operator
highlight default link zigStructure Structure
highlight default link zigExecution Special
highlight default link zigMacro Macro
highlight default link zigConditional Conditional
highlight default link zigComparatorWord Keyword
highlight default link zigRepeat Repeat
highlight default link zigSpecial Special
highlight default link zigVarDecl Function
highlight default link zigPreProc PreProc
highlight default link zigException Exception

delfunction s:syntax_keyword

let b:current_syntax = "zig"

let &cpo = s:cpo_save
unlet! s:cpo_save
