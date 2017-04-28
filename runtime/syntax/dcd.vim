" Vim syntax file
" Language:	WildPackets EtherPeek Decoder (.dcd) file
" Maintainer:	Christopher Shinn <christopher@lucent.com>
" Last Change:	2003 Apr 25

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Keywords
syn keyword dcdFunction		DCod TRTS TNXT CRLF
syn match   dcdFunction		display "\(STR\)\#"
syn keyword dcdLabel		LABL
syn region  dcdLabel		start="[A-Z]" end=";"
syn keyword dcdConditional	CEQU CNEQ CGTE CLTE CBIT CLSE
syn keyword dcdConditional	LSTS LSTE LSTZ
syn keyword dcdConditional	TYPE TTST TEQU TNEQ TGTE TLTE TBIT TLSE TSUB SKIP
syn keyword dcdConditional	MARK WHOA
syn keyword dcdConditional	SEQU SNEQ SGTE SLTE SBIT
syn match   dcdConditional	display "\(CST\)\#" "\(TST\)\#"
syn keyword dcdDisplay		HBIT DBIT BBIT
syn keyword dcdDisplay		HBYT DBYT BBYT
syn keyword dcdDisplay		HWRD DWRD BWRD
syn keyword dcdDisplay		HLNG DLNG BLNG
syn keyword dcdDisplay		D64B
syn match   dcdDisplay		display "\(HEX\)\#" "\(CHR\)\#" "\(EBC\)\#"
syn keyword dcdDisplay		HGLB DGLB BGLB
syn keyword dcdDisplay		DUMP
syn keyword dcdStatement	IPLG IPV6 ATLG AT03 AT01 ETHR TRNG PRTO PORT
syn keyword dcdStatement	TIME OSTP PSTR CSTR NBNM DMPE FTPL CKSM FCSC
syn keyword dcdStatement	GBIT GBYT GWRD GLNG
syn keyword dcdStatement	MOVE ANDG ORRG NOTG ADDG SUBG MULG DIVG MODG INCR DECR
syn keyword dcdSpecial		PRV1 PRV2 PRV3 PRV4 PRV5 PRV6 PRV7 PRV8

" Comment
syn region  dcdComment		start="\*" end="\;"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link dcdFunction		Identifier
hi def link dcdLabel		Constant
hi def link dcdConditional		Conditional
hi def link dcdDisplay		Type
hi def link dcdStatement		Statement
hi def link dcdSpecial		Special
hi def link dcdComment		Comment


let b:current_syntax = "dcd"
