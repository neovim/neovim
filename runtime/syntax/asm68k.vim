" Vim syntax file
" Language:	Motorola 68000 Assembler
" Maintainer:	Steve Wall
" Last change:	2001 May 01
"
" This is incomplete.  In particular, support for 68020 and
" up and 68851/68881 co-processors is partial or non-existant.
" Feel free to contribute...
"

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

" Partial list of register symbols
syn keyword asm68kReg	a0 a1 a2 a3 a4 a5 a6 a7 d0 d1 d2 d3 d4 d5 d6 d7
syn keyword asm68kReg	pc sr ccr sp usp ssp

" MC68010
syn keyword asm68kReg	vbr sfc sfcr dfc dfcr

" MC68020
syn keyword asm68kReg	msp isp zpc cacr caar
syn keyword asm68kReg	za0 za1 za2 za3 za4 za5 za6 za7
syn keyword asm68kReg	zd0 zd1 zd2 zd3 zd4 zd5 zd6 zd7

" MC68030
syn keyword asm68kReg	crp srp tc ac0 ac1 acusr tt0 tt1 mmusr

" MC68040
syn keyword asm68kReg	dtt0 dtt1 itt0 itt1 urp

" MC68851 registers
syn keyword asm68kReg	cal val scc crp srp drp tc ac psr pcsr
syn keyword asm68kReg	bac0 bac1 bac2 bac3 bac4 bac5 bac6 bac7
syn keyword asm68kReg	bad0 bad1 bad2 bad3 bad4 bad5 bad6 bad7

" MC68881/82 registers
syn keyword asm68kReg	fp0 fp1 fp2 fp3 fp4 fp5 fp6 fp7
syn keyword asm68kReg	control status iaddr fpcr fpsr fpiar

" M68000 opcodes - order is important!
syn match asm68kOpcode "\<abcd\(\.b\)\=\s"
syn match asm68kOpcode "\<adda\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<addi\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<addq\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<addx\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<add\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<andi\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<and\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<as[lr]\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<b[vc][cs]\(\.[bwls]\)\=\s"
syn match asm68kOpcode "\<beq\(\.[bwls]\)\=\s"
syn match asm68kOpcode "\<bg[et]\(\.[bwls]\)\=\s"
syn match asm68kOpcode "\<b[hm]i\(\.[bwls]\)\=\s"
syn match asm68kOpcode "\<bl[est]\(\.[bwls]\)\=\s"
syn match asm68kOpcode "\<bne\(\.[bwls]\)\=\s"
syn match asm68kOpcode "\<bpl\(\.[bwls]\)\=\s"
syn match asm68kOpcode "\<bchg\(\.[bl]\)\=\s"
syn match asm68kOpcode "\<bclr\(\.[bl]\)\=\s"
syn match asm68kOpcode "\<bfchg\s"
syn match asm68kOpcode "\<bfclr\s"
syn match asm68kOpcode "\<bfexts\s"
syn match asm68kOpcode "\<bfextu\s"
syn match asm68kOpcode "\<bfffo\s"
syn match asm68kOpcode "\<bfins\s"
syn match asm68kOpcode "\<bfset\s"
syn match asm68kOpcode "\<bftst\s"
syn match asm68kOpcode "\<bkpt\s"
syn match asm68kOpcode "\<bra\(\.[bwls]\)\=\s"
syn match asm68kOpcode "\<bset\(\.[bl]\)\=\s"
syn match asm68kOpcode "\<bsr\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<btst\(\.[bl]\)\=\s"
syn match asm68kOpcode "\<callm\s"
syn match asm68kOpcode "\<cas2\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<cas\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<chk2\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<chk\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<clr\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<cmpa\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<cmpi\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<cmpm\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<cmp2\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<cmp\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<db[cv][cs]\(\.w\)\=\s"
syn match asm68kOpcode "\<dbeq\(\.w\)\=\s"
syn match asm68kOpcode "\<db[ft]\(\.w\)\=\s"
syn match asm68kOpcode "\<dbg[et]\(\.w\)\=\s"
syn match asm68kOpcode "\<db[hm]i\(\.w\)\=\s"
syn match asm68kOpcode "\<dbl[est]\(\.w\)\=\s"
syn match asm68kOpcode "\<dbne\(\.w\)\=\s"
syn match asm68kOpcode "\<dbpl\(\.w\)\=\s"
syn match asm68kOpcode "\<dbra\(\.w\)\=\s"
syn match asm68kOpcode "\<div[su]\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<div[su]l\(\.l\)\=\s"
syn match asm68kOpcode "\<eori\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<eor\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<exg\(\.l\)\=\s"
syn match asm68kOpcode "\<extb\(\.l\)\=\s"
syn match asm68kOpcode "\<ext\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<illegal\>"
syn match asm68kOpcode "\<jmp\(\.[ls]\)\=\s"
syn match asm68kOpcode "\<jsr\(\.[ls]\)\=\s"
syn match asm68kOpcode "\<lea\(\.l\)\=\s"
syn match asm68kOpcode "\<link\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<ls[lr]\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<movea\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<movec\(\.l\)\=\s"
syn match asm68kOpcode "\<movem\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<movep\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<moveq\(\.l\)\=\s"
syn match asm68kOpcode "\<moves\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<move\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<mul[su]\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<nbcd\(\.b\)\=\s"
syn match asm68kOpcode "\<negx\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<neg\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<nop\>"
syn match asm68kOpcode "\<not\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<ori\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<or\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<pack\s"
syn match asm68kOpcode "\<pea\(\.l\)\=\s"
syn match asm68kOpcode "\<reset\>"
syn match asm68kOpcode "\<ro[lr]\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<rox[lr]\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<rt[dm]\s"
syn match asm68kOpcode "\<rt[ers]\>"
syn match asm68kOpcode "\<sbcd\(\.b\)\=\s"
syn match asm68kOpcode "\<s[cv][cs]\(\.b\)\=\s"
syn match asm68kOpcode "\<seq\(\.b\)\=\s"
syn match asm68kOpcode "\<s[ft]\(\.b\)\=\s"
syn match asm68kOpcode "\<sg[et]\(\.b\)\=\s"
syn match asm68kOpcode "\<s[hm]i\(\.b\)\=\s"
syn match asm68kOpcode "\<sl[est]\(\.b\)\=\s"
syn match asm68kOpcode "\<sne\(\.b\)\=\s"
syn match asm68kOpcode "\<spl\(\.b\)\=\s"
syn match asm68kOpcode "\<suba\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<subi\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<subq\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<subx\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<sub\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<swap\(\.w\)\=\s"
syn match asm68kOpcode "\<tas\(\.b\)\=\s"
syn match asm68kOpcode "\<tdiv[su]\(\.l\)\=\s"
syn match asm68kOpcode "\<t\(rap\)\=[cv][cs]\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<t\(rap\)\=eq\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<t\(rap\)\=[ft]\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<t\(rap\)\=g[et]\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<t\(rap\)\=[hm]i\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<t\(rap\)\=l[est]\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<t\(rap\)\=ne\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<t\(rap\)\=pl\(\.[wl]\)\=\s"
syn match asm68kOpcode "\<t\(rap\)\=v\>"
syn match asm68kOpcode "\<t\(rap\)\=[cv][cs]\>"
syn match asm68kOpcode "\<t\(rap\)\=eq\>"
syn match asm68kOpcode "\<t\(rap\)\=[ft]\>"
syn match asm68kOpcode "\<t\(rap\)\=g[et]\>"
syn match asm68kOpcode "\<t\(rap\)\=[hm]i\>"
syn match asm68kOpcode "\<t\(rap\)\=l[est]\>"
syn match asm68kOpcode "\<t\(rap\)\=ne\>"
syn match asm68kOpcode "\<t\(rap\)\=pl\>"
syn match asm68kOpcode "\<trap\s"
syn match asm68kOpcode "\<tst\(\.[bwl]\)\=\s"
syn match asm68kOpcode "\<unlk\s"
syn match asm68kOpcode "\<unpk\s"

" Valid labels
syn match asm68kLabel		"^[a-z_?.][a-z0-9_?.$]*$"
syn match asm68kLabel		"^[a-z_?.][a-z0-9_?.$]*\s"he=e-1
syn match asm68kLabel		"^\s*[a-z_?.][a-z0-9_?.$]*:"he=e-1

" Various number formats
syn match hexNumber		"\$[0-9a-fA-F]\+\>"
syn match hexNumber		"\<[0-9][0-9a-fA-F]*H\>"
syn match octNumber		"@[0-7]\+\>"
syn match octNumber		"\<[0-7]\+[QO]\>"
syn match binNumber		"%[01]\+\>"
syn match binNumber		"\<[01]\+B\>"
syn match decNumber		"\<[0-9]\+D\=\>"
syn match floatE		"_*E_*" contained
syn match floatExponent		"_*E_*[-+]\=[0-9]\+" contained contains=floatE
syn match floatNumber		"[-+]\=[0-9]\+_*E_*[-+]\=[0-9]\+" contains=floatExponent
syn match floatNumber		"[-+]\=[0-9]\+\.[0-9]\+\(E[-+]\=[0-9]\+\)\=" contains=floatExponent
syn match floatNumber		":\([0-9a-f]\+_*\)\+"

" Character string constants
syn match asm68kStringError	"'[ -~]*'"
syn match asm68kStringError	"'[ -~]*$"
syn region asm68kString		start="'" skip="''" end="'" oneline contains=asm68kCharError
syn match asm68kCharError	"[^ -~]" contained

" Immediate data
syn match asm68kImmediate	"#\$[0-9a-fA-F]\+" contains=hexNumber
syn match asm68kImmediate	"#[0-9][0-9a-fA-F]*H" contains=hexNumber
syn match asm68kImmediate	"#@[0-7]\+" contains=octNumber
syn match asm68kImmediate	"#[0-7]\+[QO]" contains=octNumber
syn match asm68kImmediate	"#%[01]\+" contains=binNumber
syn match asm68kImmediate	"#[01]\+B" contains=binNumber
syn match asm68kImmediate	"#[0-9]\+D\=" contains=decNumber
syn match asm68kSymbol		"[a-z_?.][a-z0-9_?.$]*" contained
syn match asm68kImmediate	"#[a-z_?.][a-z0-9_?.]*" contains=asm68kSymbol

" Special items for comments
syn keyword asm68kTodo		contained TODO

" Operators
syn match asm68kOperator	"[-+*/]"	" Must occur before Comments
syn match asm68kOperator	"\.SIZEOF\."
syn match asm68kOperator	"\.STARTOF\."
syn match asm68kOperator	"<<"		" shift left
syn match asm68kOperator	">>"		" shift right
syn match asm68kOperator	"&"		" bit-wise logical and
syn match asm68kOperator	"!"		" bit-wise logical or
syn match asm68kOperator	"!!"		" exclusive or
syn match asm68kOperator	"<>"		" inequality
syn match asm68kOperator	"="		" must be before other ops containing '='
syn match asm68kOperator	">="
syn match asm68kOperator	"<="
syn match asm68kOperator	"=="		" operand existance - used in macro definitions

" Condition code style operators
syn match asm68kOperator	"<[CV][CS]>"
syn match asm68kOperator	"<EQ>"
syn match asm68kOperator	"<G[TE]>"
syn match asm68kOperator	"<[HM]I>"
syn match asm68kOperator	"<L[SET]>"
syn match asm68kOperator	"<NE>"
syn match asm68kOperator	"<PL>"

" Comments
syn match asm68kComment		";.*" contains=asm68kTodo
syn match asm68kComment		"\s!.*"ms=s+1 contains=asm68kTodo
syn match asm68kComment		"^\s*[*!].*" contains=asm68kTodo

" Include
syn match asm68kInclude		"\<INCLUDE\s"

" Standard macros
syn match asm68kCond		"\<IF\(\.[BWL]\)\=\s"
syn match asm68kCond		"\<THEN\(\.[SL]\)\=\>"
syn match asm68kCond		"\<ELSE\(\.[SL]\)\=\>"
syn match asm68kCond		"\<ENDI\>"
syn match asm68kCond		"\<BREAK\(\.[SL]\)\=\>"
syn match asm68kRepeat		"\<FOR\(\.[BWL]\)\=\s"
syn match asm68kRepeat		"\<DOWNTO\s"
syn match asm68kRepeat		"\<TO\s"
syn match asm68kRepeat		"\<BY\s"
syn match asm68kRepeat		"\<DO\(\.[SL]\)\=\>"
syn match asm68kRepeat		"\<ENDF\>"
syn match asm68kRepeat		"\<NEXT\(\.[SL]\)\=\>"
syn match asm68kRepeat		"\<REPEAT\>"
syn match asm68kRepeat		"\<UNTIL\(\.[BWL]\)\=\s"
syn match asm68kRepeat		"\<WHILE\(\.[BWL]\)\=\s"
syn match asm68kRepeat		"\<ENDW\>"

" Macro definition
syn match asm68kMacro		"\<MACRO\>"
syn match asm68kMacro		"\<LOCAL\s"
syn match asm68kMacro		"\<MEXIT\>"
syn match asm68kMacro		"\<ENDM\>"
syn match asm68kMacroParam	"\\[0-9]"

" Conditional assembly
syn match asm68kPreCond		"\<IFC\s"
syn match asm68kPreCond		"\<IFDEF\s"
syn match asm68kPreCond		"\<IFEQ\s"
syn match asm68kPreCond		"\<IFGE\s"
syn match asm68kPreCond		"\<IFGT\s"
syn match asm68kPreCond		"\<IFLE\s"
syn match asm68kPreCond		"\<IFLT\s"
syn match asm68kPreCond		"\<IFNC\>"
syn match asm68kPreCond		"\<IFNDEF\s"
syn match asm68kPreCond		"\<IFNE\s"
syn match asm68kPreCond		"\<ELSEC\>"
syn match asm68kPreCond		"\<ENDC\>"

" Loop control
syn match asm68kPreCond		"\<REPT\s"
syn match asm68kPreCond		"\<IRP\s"
syn match asm68kPreCond		"\<IRPC\s"
syn match asm68kPreCond		"\<ENDR\>"

" Directives
syn match asm68kDirective	"\<ALIGN\s"
syn match asm68kDirective	"\<CHIP\s"
syn match asm68kDirective	"\<COMLINE\s"
syn match asm68kDirective	"\<COMMON\(\.S\)\=\s"
syn match asm68kDirective	"\<DC\(\.[BWLSDXP]\)\=\s"
syn match asm68kDirective	"\<DC\.\\[0-9]\s"me=e-3	" Special use in a macro def
syn match asm68kDirective	"\<DCB\(\.[BWLSDXP]\)\=\s"
syn match asm68kDirective	"\<DS\(\.[BWLSDXP]\)\=\s"
syn match asm68kDirective	"\<END\>"
syn match asm68kDirective	"\<EQU\s"
syn match asm68kDirective	"\<FEQU\(\.[SDXP]\)\=\s"
syn match asm68kDirective	"\<FAIL\>"
syn match asm68kDirective	"\<FOPT\s"
syn match asm68kDirective	"\<\(NO\)\=FORMAT\>"
syn match asm68kDirective	"\<IDNT\>"
syn match asm68kDirective	"\<\(NO\)\=LIST\>"
syn match asm68kDirective	"\<LLEN\s"
syn match asm68kDirective	"\<MASK2\>"
syn match asm68kDirective	"\<NAME\s"
syn match asm68kDirective	"\<NOOBJ\>"
syn match asm68kDirective	"\<OFFSET\s"
syn match asm68kDirective	"\<OPT\>"
syn match asm68kDirective	"\<ORG\(\.[SL]\)\=\>"
syn match asm68kDirective	"\<\(NO\)\=PAGE\>"
syn match asm68kDirective	"\<PLEN\s"
syn match asm68kDirective	"\<REG\s"
syn match asm68kDirective	"\<RESTORE\>"
syn match asm68kDirective	"\<SAVE\>"
syn match asm68kDirective	"\<SECT\(\.S\)\=\s"
syn match asm68kDirective	"\<SECTION\(\.S\)\=\s"
syn match asm68kDirective	"\<SET\s"
syn match asm68kDirective	"\<SPC\s"
syn match asm68kDirective	"\<TTL\s"
syn match asm68kDirective	"\<XCOM\s"
syn match asm68kDirective	"\<XDEF\s"
syn match asm68kDirective	"\<XREF\(\.S\)\=\s"

syn case match

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_asm68k_syntax_inits")
  if version < 508
    let did_asm68k_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " The default methods for highlighting.  Can be overridden later
  " Comment Constant Error Identifier PreProc Special Statement Todo Type
  "
  " Constant		Boolean Character Number String
  " Identifier		Function
  " PreProc		Define Include Macro PreCondit
  " Special		Debug Delimiter SpecialChar SpecialComment Tag
  " Statement		Conditional Exception Keyword Label Operator Repeat
  " Type		StorageClass Structure Typedef

  HiLink asm68kComment		Comment
  HiLink asm68kTodo		Todo

  HiLink hexNumber		Number		" Constant
  HiLink octNumber		Number		" Constant
  HiLink binNumber		Number		" Constant
  HiLink decNumber		Number		" Constant
  HiLink floatNumber		Number		" Constant
  HiLink floatExponent		Number		" Constant
  HiLink floatE			SpecialChar	" Statement
  "HiLink floatE		Number		" Constant

  HiLink asm68kImmediate	SpecialChar	" Statement
  "HiLink asm68kSymbol		Constant

  HiLink asm68kString		String		" Constant
  HiLink asm68kCharError	Error
  HiLink asm68kStringError	Error

  HiLink asm68kReg		Identifier
  HiLink asm68kOperator		Identifier

  HiLink asm68kInclude		Include		" PreProc
  HiLink asm68kMacro		Macro		" PreProc
  HiLink asm68kMacroParam	Keyword		" Statement

  HiLink asm68kDirective	Special
  HiLink asm68kPreCond		Special


  HiLink asm68kOpcode		Statement
  HiLink asm68kCond		Conditional	" Statement
  HiLink asm68kRepeat		Repeat		" Statement

  HiLink asm68kLabel		Type
  delcommand HiLink
endif

let b:current_syntax = "asm68k"

" vim: ts=8 sw=2
