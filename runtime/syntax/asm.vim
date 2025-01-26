" Vim syntax file
" Language:		GNU Assembler
" Maintainer:		Doug Kearns dougkearns@gmail.com
" Previous Maintainers: Erik Wognsen <erik.wognsen@gmail.com>
"			Kevin Dahlhausen <kdahlhaus@yahoo.com>
" Contributors:		Ori Avtalion, Lakshay Garg, Nir Lichtman
" Last Change:		2025 Jan 26

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case ignore

" storage types
syn match asmType "\.long"
syn match asmType "\.ascii"
syn match asmType "\.asciz"
syn match asmType "\.byte"
syn match asmType "\.double"
syn match asmType "\.float"
syn match asmType "\.hword"
syn match asmType "\.int"
syn match asmType "\.octa"
syn match asmType "\.quad"
syn match asmType "\.short"
syn match asmType "\.single"
syn match asmType "\.space"
syn match asmType "\.string"
syn match asmType "\.word"
syn match asmType "\.2byte"
syn match asmType "\.4byte"
syn match asmType "\.8byte"

syn match asmIdentifier		"[a-z_][a-z0-9_]*"
syn match asmLabel		"[a-z_][a-z0-9_]*:"he=e-1

" Various #'s as defined by GAS ref manual sec 3.6.2.1
" Technically, the first asmDecimal def is actually octal,
" since the value of 0-7 octal is the same as 0-7 decimal,
" I (Kevin) prefer to map it as decimal:
syn match asmDecimal		"\<0\+[1-7]\=\>"	 display
syn match asmDecimal		"\<[1-9]\d*\>"		 display
syn match asmOctal		"\<0[0-7][0-7]\+\>"	 display
syn match asmHexadecimal	"\<0[xX][0-9a-fA-F]\+\>" display
syn match asmBinary		"\<0[bB][0-1]\+\>"	 display

syn match asmFloat		"\<\d\+\.\d*\%(e[+-]\=\d\+\)\=\>" display
syn match asmFloat		"\.\d\+\%(e[+-]\=\d\+\)\=\>"	  display
syn match asmFloat		"\<\d\%(e[+-]\=\d\+\)\>"	  display
syn match asmFloat		"[+-]\=Inf\>\|\<NaN\>"		  display

syn match asmFloat		"\%(0[edfghprs]\)[+-]\=\d*\%(\.\d\+\)\%(e[+-]\=\d\+\)\="    display
syn match asmFloat		"\%(0[edfghprs]\)[+-]\=\d\+\%(\.\d\+\)\=\%(e[+-]\=\d\+\)\=" display
" Avoid fighting the hexadecimal match for unicorn-like '0x' prefixed floats
syn match asmFloat		"\%(0x\)[+-]\=\d*\%(\.\d\+\)\%(e[+-]\=\d\+\)\="		    display

" Allow all characters to be escaped (and in strings) as these vary across
" architectures [See sec 3.6.1.1 Strings]
syn match asmCharacterEscape	"\\."    contained
syn match asmCharacter		"'\\\=." contains=asmCharacterEscape

syn match asmStringEscape	"\\\_."			contained
syn match asmStringEscape	"\\\%(\o\{3}\|00[89]\)"	contained display
syn match asmStringEscape	"\\x\x\+"		contained display

syn region asmString		start="\"" end="\"" skip="\\\\\|\\\"" contains=asmStringEscape

syn keyword asmTodo		contained TODO FIXME XXX NOTE

" GAS supports one type of multi line comments:
syn region asmComment		start="/\*" end="\*/" contains=asmTodo,@Spell

" GAS (undocumentedly?) supports C++ style comments. Unlike in C/C++ however,
" a backslash ending a C++ style comment does not extend the comment to the
" next line (hence the syntax region does not define 'skip="\\$"')
syn region asmComment		start="//" end="$" keepend contains=asmTodo,@Spell

" Line comment characters depend on the target architecture and command line
" options and some comments may double as logical line number directives or
" preprocessor commands. This situation is described at
" http://sourceware.org/binutils/docs-2.22/as/Comments.html
" Some line comment characters have other meanings for other targets. For
" example, .type directives may use the `@' character which is also an ARM
" comment marker.
" As a compromise to accommodate what I arbitrarily assume to be the most
" frequently used features of the most popular architectures (and also the
" non-GNU assembly languages that use this syntax file because their asm files
" are also named *.asm), the following are used as line comment characters:
syn match asmComment		"[#;!|].*" contains=asmTodo,@Spell

" Side effects of this include:
" - When `;' is used to separate statements on the same line (many targets
"   support this), all statements except the first get highlighted as
"   comments. As a remedy, remove `;' from the above.
" - ARM comments are not highlighted correctly. For ARM, uncomment the
"   following two lines and comment the one above.
"syn match asmComment		"@.*" contains=asmTodo
"syn match asmComment		"^#.*" contains=asmTodo

" Advanced users of specific architectures will probably want to change the
" comment highlighting or use a specific, more comprehensive syntax file.

syn match asmInclude		"\.include"
syn match asmCond		"\.if"
syn match asmCond		"\.else"
syn match asmCond		"\.endif"
syn match asmMacro		"\.macro"
syn match asmMacro		"\.endm"

" Assembler directives start with a '.' and may contain upper case (e.g.,
" .ABORT), numbers (e.g., .p2align), dash (e.g., .app-file) and underscore in
" CFI directives (e.g., .cfi_startproc). This will also match labels starting
" with '.', including the GCC auto-generated '.L' labels.
syn match asmDirective		"\.[A-Za-z][0-9A-Za-z-_]*"

syn case match

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" The default methods for highlighting.  Can be overridden later
hi def link asmSection		Special
hi def link asmLabel		Label
hi def link asmComment		Comment
hi def link asmTodo		Todo
hi def link asmDirective	Statement

hi def link asmInclude		Include
hi def link asmCond		PreCondit
hi def link asmMacro		Macro

if exists('g:asm_legacy_syntax_groups')
  hi def link hexNumber		Number
  hi def link decNumber		Number
  hi def link octNumber		Number
  hi def link binNumber		Number
  hi def link asmHexadecimal	hexNumber
  hi def link asmDecimal	decNumber
  hi def link asmOctal		octNumber
  hi def link asmBinary		binNumber
else
  hi def link asmHexadecimal	Number
  hi def link asmDecimal	Number
  hi def link asmOctal		Number
  hi def link asmBinary		Number
endif
hi def link asmFloat		Float

hi def link asmString		String
hi def link asmStringEscape	Special
hi def link asmCharacter	Character
hi def link asmCharacterEscape	Special

hi def link asmIdentifier	Identifier
hi def link asmType		Type

let b:current_syntax = "asm"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet
