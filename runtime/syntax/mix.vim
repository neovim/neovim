" Vim syntax file
" Language:	MIX (Donald Knuth's assembly language used in TAOCP)
" Maintainer:	Wu Yongwei <wuyongwei@gmail.com>
" Filenames:	*.mixal *.mix
" Last Change:  2017-11-26 15:21:36 +0800

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case ignore

" Special processing of ALF directive: implementations vary whether quotation
" marks are needed
syn match mixAlfParam		#\s\{1,2\}"\?[^"]\{,5\}"\?# contains=mixString nextgroup=mixEndComment contained

" Region for parameters
syn match mixParam		#[-+*/:=0-9a-z,()"]\+# contains=mixIdentifier,mixSpecial,mixNumber,mixString,mixLabel nextgroup=mixEndComment contained

" Comment at the line end
syn match mixEndComment		".*" contains=mixRegister contained

" Identifier; must go before literals
syn match mixIdentifier		"[a-z0-9_]\+" contained

" Literals
syn match mixSpecial		"[-+*/:=]" contained
syn match mixNumber		"[0-9]\+\>" contained
syn region mixString		start=+"+ skip=+\\"+ end=+"+ contained

" Labels
syn match mixLabel		"^[a-z0-9_]\{,10\}\s\+" nextgroup=mixAlfSpecial,mixOpcode,mixDirective
syn match mixLabel		"[0-9][BF]" contained

" Comments
syn match mixComment		"^\*.*" contains=mixRegister

" Directives
syn keyword mixDirective 	ORIG EQU CON END nextgroup=mixParam contained skipwhite
syn keyword mixDirective 	ALF nextgroup=mixAlfParam contained

" Opcodes
syn keyword mixOpcode	NOP HLT NUM CHAR FLOT FIX nextgroup=mixEndComment contained
syn keyword mixOpcode	FADD FSUB FMUL FDIV FCMP MOVE ADD SUB MUL DIV IOC IN OUT JRED JBUS JMP JSJ JOV JNOV JL JE JG JLE JNE JGE SLA SRA SLAX SRAX SLC SRC nextgroup=mixParam contained skipwhite
syn keyword mixOpcode	SLB SRB JAE JAO JXE JXO nextgroup=mixParam contained skipwhite

syn match mixOpcode	"LD[AX1-6]N\?\>" nextgroup=mixParam contained skipwhite
syn match mixOpcode	"ST[AX1-6JZ]\>" nextgroup=mixParam contained skipwhite
syn match mixOpcode	"EN[TN][AX1-6]\>" nextgroup=mixParam contained skipwhite
syn match mixOpcode	"INC[AX1-6]\>" nextgroup=mixParam contained skipwhite
syn match mixOpcode	"DEC[AX1-6]\>" nextgroup=mixParam contained skipwhite
syn match mixOpcode	"CMP[AX1-6]\>" nextgroup=mixParam contained skipwhite
syn match mixOpcode	"J[AX1-6]N\?[NZP]\>" nextgroup=mixParam contained skipwhite

" Switch back to being case sensitive
syn case match

" Registers (only to be used in comments now)
syn keyword mixRegister	rA rX rI1 rI2 rI3 rI4 rI5 rI6 rJ contained

" The default highlighting
hi def link mixRegister		Special
hi def link mixLabel		Define
hi def link mixComment		Comment
hi def link mixEndComment	Comment
hi def link mixDirective	Keyword
hi def link mixOpcode		Keyword

hi def link mixSpecial		Special
hi def link mixNumber		Number
hi def link mixString		String
hi def link mixAlfParam		String
hi def link mixIdentifier	Identifier

let b:current_syntax = "mix"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8
