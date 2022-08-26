" Vim syntax file
" Language:	Z80 assembler asz80
" Maintainer:	Milan Pikula <www@fornax.elf.stuba.sk>
" Last Change:	2003 May 11

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

" Common Z80 Assembly instructions
syn keyword z8aInstruction adc add and bit ccf cp cpd cpdr cpi cpir cpl
syn keyword z8aInstruction daa di djnz ei exx halt im in
syn keyword z8aInstruction ind ini indr inir jp jr ld ldd lddr ldi ldir
syn keyword z8aInstruction neg nop or otdr otir out outd outi
syn keyword z8aInstruction res rl rla rlc rlca rld
syn keyword z8aInstruction rr rra rrc rrca rrd sbc scf set sla sra
syn keyword z8aInstruction srl sub xor
" syn keyword z8aInstruction push pop call ret reti retn inc dec ex rst

" Any other stuff
syn match z8aIdentifier		"[a-z_][a-z0-9_]*"

" Instructions changing stack
syn keyword z8aSpecInst push pop call ret reti retn rst
syn match z8aInstruction "\<inc\>"
syn match z8aInstruction "\<dec\>"
syn match z8aInstruction "\<ex\>"
syn match z8aSpecInst "\<inc\s\+sp\>"me=s+3
syn match z8aSpecInst "\<dec\s\+sp\>"me=s+3
syn match z8aSpecInst "\<ex\s\+(\s*sp\s*)\s*,\s*hl\>"me=s+2

"Labels
syn match z8aLabel		"[a-z_][a-z0-9_]*:"
syn match z8aSpecialLabel	"[a-z_][a-z0-9_]*::"

" PreProcessor commands
syn match z8aPreProc	"\.org"
syn match z8aPreProc	"\.globl"
syn match z8aPreProc	"\.db"
syn match z8aPreProc	"\.dw"
syn match z8aPreProc	"\.ds"
syn match z8aPreProc	"\.byte"
syn match z8aPreProc	"\.word"
syn match z8aPreProc	"\.blkb"
syn match z8aPreProc	"\.blkw"
syn match z8aPreProc	"\.ascii"
syn match z8aPreProc	"\.asciz"
syn match z8aPreProc	"\.module"
syn match z8aPreProc	"\.title"
syn match z8aPreProc	"\.sbttl"
syn match z8aPreProc	"\.even"
syn match z8aPreProc	"\.odd"
syn match z8aPreProc	"\.area"
syn match z8aPreProc	"\.page"
syn match z8aPreProc	"\.setdp"
syn match z8aPreProc	"\.radix"
syn match z8aInclude	"\.include"
syn match z8aPreCondit	"\.if"
syn match z8aPreCondit	"\.else"
syn match z8aPreCondit	"\.endif"

" Common strings
syn match z8aString		"\".*\""
syn match z8aString		"\'.*\'"

" Numbers
syn match z8aNumber		"[0-9]\+"
syn match z8aNumber		"0[xXhH][0-9a-fA-F]\+"
syn match z8aNumber		"0[bB][0-1]*"
syn match z8aNumber		"0[oO\@qQ][0-7]\+"
syn match z8aNumber		"0[dD][0-9]\+"

" Character constant
syn match z8aString		"\#\'."hs=s+1

" Comments
syn match z8aComment		";.*"

syn case match

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link z8aSection		Special
hi def link z8aLabel		Label
hi def link z8aSpecialLabel	Label
hi def link z8aComment		Comment
hi def link z8aInstruction	Statement
hi def link z8aSpecInst		Statement
hi def link z8aInclude		Include
hi def link z8aPreCondit		PreCondit
hi def link z8aPreProc		PreProc
hi def link z8aNumber		Number
hi def link z8aString		String


let b:current_syntax = "z8a"
" vim: ts=8
