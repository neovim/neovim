" Vim syn file
" Language:	Altera AHDL
" Maintainer:	John Cook <john.cook@kla-tencor.com>
" Last Change:	2001 Apr 25

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

"this language is oblivious to case.
syn case ignore

" a bunch of keywords
syn keyword ahdlKeyword assert begin bidir bits buried case clique
syn keyword ahdlKeyword connected_pins constant defaults define design
syn keyword ahdlKeyword device else elsif end for function generate
syn keyword ahdlKeyword gnd help_id if in include input is machine
syn keyword ahdlKeyword node of options others output parameters
syn keyword ahdlKeyword returns states subdesign table then title to
syn keyword ahdlKeyword tri_state_node variable vcc when with

" a bunch of types
syn keyword ahdlIdentifier carry cascade dffe dff exp global
syn keyword ahdlIdentifier jkffe jkff latch lcell mcell memory opendrn
syn keyword ahdlIdentifier soft srffe srff tffe tff tri wire x

syn keyword ahdlMegafunction lpm_and lpm_bustri lpm_clshift lpm_constant
syn keyword ahdlMegafunction lpm_decode lpm_inv lpm_mux lpm_or lpm_xor
syn keyword ahdlMegafunction busmux mux

syn keyword ahdlMegafunction divide lpm_abs lpm_add_sub lpm_compare
syn keyword ahdlMegafunction lpm_counter lpm_mult

syn keyword ahdlMegafunction altdpram csfifo dcfifo scfifo csdpram lpm_ff
syn keyword ahdlMegafunction lpm_latch lpm_shiftreg lpm_ram_dq lpm_ram_io
syn keyword ahdlMegafunction lpm_rom lpm_dff lpm_tff clklock pll ntsc

syn keyword ahdlTodo contained TODO

" String constants
syn region ahdlString start=+"+  skip=+\\"+  end=+"+

" valid integer number formats (decimal, binary, octal, hex)
syn match ahdlNumber '\<\d\+\>'
syn match ahdlNumber '\<b"\(0\|1\|x\)\+"'
syn match ahdlNumber '\<\(o\|q\)"\o\+"'
syn match ahdlNumber '\<\(h\|x\)"\x\+"'

" operators
syn match   ahdlOperator "[!&#$+\-<>=?:\^]"
syn keyword ahdlOperator not and nand or nor xor xnor
syn keyword ahdlOperator mod div log2 used ceil floor

" one line and multi-line comments
" (define these after ahdlOperator so -- overrides -)
syn match  ahdlComment "--.*" contains=ahdlNumber,ahdlTodo
syn region ahdlComment start="%" end="%" contains=ahdlNumber,ahdlTodo

" other special characters
syn match   ahdlSpecialChar "[\[\]().,;]"

syn sync minlines=1

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" The default highlighting.
hi def link ahdlNumber		ahdlString
hi def link ahdlMegafunction	ahdlIdentifier
hi def link ahdlSpecialChar	SpecialChar
hi def link ahdlKeyword		Statement
hi def link ahdlString		String
hi def link ahdlComment		Comment
hi def link ahdlIdentifier		Identifier
hi def link ahdlOperator		Operator
hi def link ahdlTodo		Todo


let b:current_syntax = "ahdl"
" vim:ts=8
