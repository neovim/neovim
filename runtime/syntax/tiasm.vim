" Vim syntax file
" Language:	TI linear assembly language
" Document:	https://downloads.ti.com/docs/esd/SPRUI03B/#SPRUI03B_HTML/assembler-description.html
" Maintainer:	Wu, Zhenyu <wuzhenyu@ustc.edu>
" Last Change:	2025 Jan 08

if exists("b:current_syntax")
  finish
endif

syn case ignore

" storage types
syn match tiasmType "\.bits"
syn match tiasmType "\.byte"
syn match tiasmType "\.char"
syn match tiasmType "\.cstring"
syn match tiasmType "\.double"
syn match tiasmType "\.field"
syn match tiasmType "\.float"
syn match tiasmType "\.half"
syn match tiasmType "\.int"
syn match tiasmType "\.long"
syn match tiasmType "\.short"
syn match tiasmType "\.string"
syn match tiasmType "\.ubyte"
syn match tiasmType "\.uchar"
syn match tiasmType "\.uhalf"
syn match tiasmType "\.uint"
syn match tiasmType "\.ulong"
syn match tiasmType "\.ushort"
syn match tiasmType "\.uword"
syn match tiasmType "\.word"

syn match tiasmIdentifier		"[a-z_][a-z0-9_]*"

syn match tiasmDecimal		"\<[1-9]\d*\>"		 display
syn match tiasmOctal		"\<0[0-7][0-7]\+\>\|\<[0-7]\+[oO]\>"	 display
syn match tiasmHexadecimal	"\<0[xX][0-9a-fA-F]\+\>\|\<[0-9][0-9a-fA-F]*[hH]\>" display
syn match tiasmBinary		"\<0[bB][0-1]\+\>\|\<[01]\+[bB]\>"	 display

syn match tiasmFloat		"\<\d\+\.\d*\%(e[+-]\=\d\+\)\=\>" display
syn match tiasmFloat		"\<\d\%(e[+-]\=\d\+\)\>"	  display

syn match tiasmCharacter		"'.'\|''\|'[^']'"

syn region tiasmString		start="\"" end="\"" skip="\"\""

syn match tiasmFunction		"\$[a-zA-Z_][a-zA-Z_0-9]*\ze("

syn keyword tiasmTodo			contained TODO FIXME XXX NOTE
syn region tiasmComment			start=";" end="$" keepend contains=tiasmTodo,@Spell
syn match tiasmComment			"^[*!].*" contains=tiasmTodo,@Spell
syn match tiasmLabel			"^[^ *!;][^ :]*"

syn match tiasmInclude		"\.include"
syn match tiasmCond		"\.if"
syn match tiasmCond		"\.else"
syn match tiasmCond		"\.endif"
syn match tiasmMacro		"\.macro"
syn match tiasmMacro		"\.endm"

syn match tiasmDirective		"\.[A-Za-z][0-9A-Za-z-_]*"

syn case match

hi def link tiasmLabel		Label
hi def link tiasmComment		Comment
hi def link tiasmTodo		Todo
hi def link tiasmDirective	Statement

hi def link tiasmInclude		Include
hi def link tiasmCond		PreCondit
hi def link tiasmMacro		Macro

if exists('g:tiasm_legacy_syntax_groups')
  hi def link hexNumber		Number
  hi def link decNumber		Number
  hi def link octNumber		Number
  hi def link binNumber		Number
  hi def link tiasmHexadecimal	hexNumber
  hi def link tiasmDecimal	decNumber
  hi def link tiasmOctal		octNumber
  hi def link tiasmBinary		binNumber
else
  hi def link tiasmHexadecimal	Number
  hi def link tiasmDecimal	Number
  hi def link tiasmOctal		Number
  hi def link tiasmBinary		Number
endif
hi def link tiasmFloat		Float

hi def link tiasmString		String
hi def link tiasmStringEscape	Special
hi def link tiasmCharacter	Character
hi def link tiasmCharacterEscape	Special

hi def link tiasmIdentifier	Identifier
hi def link tiasmType		Type
hi def link tiasmFunction	Function

let b:current_syntax = "tiasm"
