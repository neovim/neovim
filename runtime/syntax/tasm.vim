" Vim syntax file
" Language: TASM: turbo assembler by Borland
" Maintaner: FooLman of United Force <foolman@bigfoot.com>
" Last Change: 2012 Feb 03 by Thilo Six

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case ignore
syn match tasmLabel "^[\ \t]*[@a-z_$][a-z0-9_$@]*\ *:"
syn keyword tasmDirective ALIAS ALIGN ARG ASSUME %BIN CATSRT CODESEG
syn match tasmDirective "\<\(byte\|word\|dword\|qword\)\ ptr\>"
" CALL extended syntax
syn keyword tasmDirective COMM %CONDS CONST %CREF %CREFALL %CREFREF
syn keyword tasmDirective %CREFUREF %CTLS DATASEG DB DD %DEPTH DF DISPLAY
syn keyword tasmDirective DOSSEG DP DQ DT DW ELSE EMUL END ENDIF
" IF XXXX
syn keyword tasmDirective ENDM ENDP ENDS ENUM EQU ERR EVEN EVENDATA EXITCODE
syn keyword tasmDirective EXITM EXTRN FARDATA FASTIMUL FLIPFLAG GETFIELD GLOBAL
syn keyword tasmDirective GOTO GROUP IDEAL %INCL INCLUDE INCLUDELIB INSTR IRP
"JMP
syn keyword tasmDirective IRPC JUMPS LABEL LARGESTACK %LINUM %LIST LOCAL
syn keyword tasmDirective LOCALS MACRO %MACS MASKFLAG MASM MASM51 MODEL
syn keyword tasmDirective MULTERRS NAME %NEWPAGE %NOCONDS %NOCREF %NOCTLS
syn keyword tasmDirective NOEMUL %NOINCL NOJUMPS %NOLIST NOLOCALS %NOMACS
syn keyword tasmDirective NOMASM51 NOMULTERRS NOSMART %NOSYMS %NOTRUNC NOWARN
syn keyword tasmDirective %PAGESIZE %PCNT PNO87 %POPLCTL POPSTATE PROC PROCDESC
syn keyword tasmDirective PROCTYPE PUBLIC PUBLICDLL PURGE %PUSHCTL PUSHSTATE
"rept, ret
syn keyword tasmDirective QUIRKS RADIX RECORD RETCODE SEGMENT SETFIELD
syn keyword tasmDirective SETFLAG SIZESTR SMALLSTACK SMART STACK STARTUPCODE
syn keyword tasmDirective STRUC SUBSTR %SUBTTL %SYMS TABLE %TABSIZE TBLINIT
syn keyword tasmDirective TBLINST TBLPTR TESTFLAG %TEXT %TITLE %TRUNC TYPEDEF
syn keyword tasmDirective UDATASEG UFARDATA UNION USES VERSION WAR WHILE ?DEBUG

syn keyword tasmInstruction AAA AAD AAM AAS ADC ADD AND ARPL BOUND BSF BSR
syn keyword tasmInstruction BSWAP BT BTC BTR BTS CALL CBW CLC CLD CLI CLTS
syn keyword tasmInstruction CMC CMP CMPXCHG CMPXCHG8B CPUID CWD CDQ CWDE
syn keyword tasmInstruction DAA DAS DEC DIV ENTER RETN RETF F2XM1
syn keyword tasmCoprocInstr FABS FADD FADDP FBLD FBSTP FCHG FCOM FCOM2 FCOMI
syn keyword tasmCoprocInstr FCOMIP FCOMP FCOMP3 FCOMP5 FCOMPP FCOS FDECSTP
syn keyword tasmCoprocInstr FDISI FDIV FDIVP FDIVR FENI FFREE FFREEP FIADD
syn keyword tasmCoprocInstr FICOM FICOMP FIDIV FIDIVR FILD FIMUL FINIT FINCSTP
syn keyword tasmCoprocInstr FIST FISTP FISUB FISUBR FLD FLD1 FLDCW FLDENV
syn keyword tasmCoprocInstr FLDL2E FLDL2T FLDLG2 FLDLN2 FLDPI FLDZ FMUL FMULP
syn keyword tasmCoprocInstr FNCLEX FNINIT FNOP FNSAVE FNSTCW FNSTENV FNSTSW
syn keyword tasmCoprocInstr FPATAN FPREM FPREM1 FPTAN FRNDINT FRSTOR FSCALE
syn keyword tasmCoprocInstr FSETPM FSIN FSINCOM FSQRT FST FSTP FSTP1 FSTP8
syn keyword tasmCoprocInstr FSTP9 FSUB FSUBP FSUBR FSUBRP FTST FUCOM FUCOMI
syn keyword tasmCoprocInstr FUCOMPP FWAIT FXAM FXCH FXCH4 FXCH7 FXTRACT FYL2X
syn keyword tasmCoprocInstr FYL2XP1 FSTCW FCHS FSINCOS
syn keyword tasmInstruction IDIV IMUL IN INC INT INTO INVD INVLPG IRET JMP
syn keyword tasmInstruction LAHF LAR LDS LEA LEAVE LES LFS LGDT LGS LIDT LLDT
syn keyword tasmInstruction LMSW LOCK LODSB LSL LSS LTR MOV MOVSX MOVZX MUL
syn keyword tasmInstruction NEG NOP NOT OR OUT POP POPA POPAD POPF POPFD PUSH
syn keyword tasmInstruction PUSHA PUSHAD PUSHF PUSHFD RCL RCR RDMSR RDPMC RDTSC
syn keyword tasmInstruction REP RET ROL ROR RSM SAHF SAR SBB SGDT SHL SAL SHLD
syn keyword tasmInstruction SHR SHRD SIDT SMSW STC STD STI STR SUB TEST VERR
syn keyword tasmInstruction VERW WBINVD WRMSR XADD XCHG XLAT XOR
syn keyword tasmMMXinst     EMMS MOVD MOVQ PACKSSDW PACKSSWB PACKUSWB PADDB
syn keyword tasmMMXinst     PADDD PADDSB PADDSB PADDSW PADDUSB PADDUSW PADDW
syn keyword tasmMMXinst     PAND PANDN PCMPEQB PCMPEQD PCMPEQW PCMPGTB PCMPGTD
syn keyword tasmMMXinst     PCMPGTW PMADDWD PMULHW PMULLW POR PSLLD PSLLQ
syn keyword tasmMMXinst     PSLLW PSRAD PSRAW PSRLD PSRLQ PSRLW PSUBB PSUBD
syn keyword tasmMMXinst     PSUBSB PSUBSW PSUBUSB PSUBUSW PSUBW PUNPCKHBW
syn keyword tasmMMXinst     PUNPCKHBQ PUNPCKHWD PUNPCKLBW PUNPCKLDQ PUNPCKLWD
syn keyword tasmMMXinst     PXOR
"FCMOV
syn match tasmInstruction "\<\(CMPS\|MOVS\|OUTS\|SCAS\|STOS\|LODS\|INS\)[BWD]"
syn match tasmInstruction "\<\(CMOV\|SET\|J\)N\=[ABCGLESXZ]\>"
syn match tasmInstruction "\<\(CMOV\|SET\|J\)N\=[ABGL]E\>"
syn match tasmInstruction "\<\(LOOP\|REP\)N\=[EZ]\=\>"
syn match tasmRegister "\<[A-D][LH]\>"
syn match tasmRegister "\<E\=\([A-D]X\|[SD]I\|[BS]P\)\>"
syn match tasmRegister "\<[C-GS]S\>"
syn region tasmComment start=";" end="$"
"HACK! comment ? ... selection
syn region tasmComment start="comment \+\$" end="\$"
syn region tasmComment start="comment \+\~" end="\~"
syn region tasmComment start="comment \+#" end="#"
syn region tasmString start="'" end="'"
syn region tasmString start='"' end='"'

syn match tasmDec "\<-\=[0-9]\+\.\=[0-9]*\>"
syn match tasmHex "\<[0-9][0-9A-F]*H\>"
syn match tasmOct "\<[0-7]\+O\>"
syn match tasmBin "\<[01]\+B\>"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link tasmString String
hi def link tasmDec Number
hi def link tasmHex Number
hi def link tasmOct Number
hi def link tasmBin Number
hi def link tasmInstruction Keyword
hi def link tasmCoprocInstr Keyword
hi def link tasmMMXInst	Keyword
hi def link tasmDirective PreProc
hi def link tasmRegister Identifier
hi def link tasmProctype PreProc
hi def link tasmComment Comment
hi def link tasmLabel Label


let b:curret_syntax = "tasm"

let &cpo = s:cpo_save
unlet s:cpo_save
