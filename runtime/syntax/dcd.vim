" Vim syntax file
" Language:	WildPackets EtherPeek Decoder (.dcd) file
" Maintainer:	Christopher Shinn <christopher@lucent.com>
" Last Change:	2003 Apr 25

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_dcd_syntax_inits")
  if version < 508
    let did_dcd_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink dcdFunction		Identifier
  HiLink dcdLabel		Constant
  HiLink dcdConditional		Conditional
  HiLink dcdDisplay		Type
  HiLink dcdStatement		Statement
  HiLink dcdSpecial		Special
  HiLink dcdComment		Comment

  delcommand HiLink
endif

let b:current_syntax = "dcd"
