" Vim syntax file
" Language:	NASM - The Netwide Assembler (v0.98)
" Maintainer:	Andrii Sokolov	<andriy145@gmail.com>
" Original Author:	Manuel M.H. Stol	<Manuel.Stol@allieddata.nl>
" Former Maintainer:	Manuel M.H. Stol	<Manuel.Stol@allieddata.nl>
" Contributors:
" 	Leonard König <leonard.r.koenig@gmail.com> (C string highlighting),
" 	Peter Stanhope <dev.rptr@gmail.com> (Add missing 64-bit mode registers)
" 	Frédéric Hamel <frederic.hamel123@gmail.com> (F16c support, partial AVX
" 						     support, other)
"	sarvel <sarvel@protonmail.com> (Complete set of supported instructions)
" Last Change:	2024 Oct 8
" NASM Home:	http://www.nasm.us/


" Setup Syntax:
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif
"  Assembler syntax is case insensetive
syn case ignore


" Vim search and movement commands on identifers
"  Comments at start of a line inside which to skip search for indentifiers
setlocal comments=:;
"  Identifier Keyword characters (defines \k)
setlocal iskeyword=@,48-57,#,$,.,?,@-@,_,~


" Comments:
syn region  nasmComment		start=";" keepend end="$" contains=@nasmGrpInComments
syn region  nasmSpecialComment	start=";\*\*\*" keepend end="$"
syn keyword nasmInCommentTodo	contained TODO FIXME XXX[XXXXX]
syn cluster nasmGrpInComments	contains=nasmInCommentTodo
syn cluster nasmGrpComments	contains=@nasmGrpInComments,nasmComment,nasmSpecialComment



" Label Identifiers:
"  in NASM: 'Everything is a Label'
"  Definition Label = label defined by %[i]define or %[i]assign
"  Identifier Label = label defined as first non-keyword on a line or %[i]macro
syn match   nasmLabelError	"$\=\(\d\+\K\|[#.@]\|\$\$\k\)\k*\>"
syn match   nasmLabel		"\<\(\h\|[?@]\)\k*\>"
syn match   nasmLabel		"[\$\~]\(\h\|[?@]\)\k*\>"lc=1
"  Labels starting with one or two '.' are special
syn match   nasmLocalLabel	"\<\.\(\w\|[#$?@~]\)\k*\>"
syn match   nasmLocalLabel	"\<\$\.\(\w\|[#$?@~]\)\k*\>"ms=s+1
if !exists("nasm_no_warn")
  syn match  nasmLabelWarn	"\<\~\=\$\=[_.][_.\~]*\>"
endif
if exists("nasm_loose_syntax")
  syn match   nasmSpecialLabel	"\<\.\.@\k\+\>"
  syn match   nasmSpecialLabel	"\<\$\.\.@\k\+\>"ms=s+1
  if !exists("nasm_no_warn")
    syn match   nasmLabelWarn	"\<\$\=\.\.@\(\d\|[#$\.~]\)\k*\>"
  endif
  " disallow use of nasm internal label format
  syn match   nasmLabelError	"\<\$\=\.\.@\d\+\.\k*\>"
else
  syn match   nasmSpecialLabel	"\<\.\.@\(\h\|[?@]\)\k*\>"
  syn match   nasmSpecialLabel	"\<\$\.\.@\(\h\|[?@]\)\k*\>"ms=s+1
endif
"  Labels can be dereferenced with '$' to destinguish them from reserved words
syn match   nasmLabelError	"\<\$\K\k*\s*:"
syn match   nasmLabelError	"^\s*\$\K\k*\>"
syn match   nasmLabelError	"\<\~\s*\(\k*\s*:\|\$\=\.\k*\)"



" Constants:
syn match   nasmStringError	+["'`]+
" NASM is case sensitive here: eg. u-prefix allows for 4-digit, U-prefix for
" 8-digit Unicode characters
syn case match
" one-char escape-sequences
syn match   nasmCStringEscape  display contained "\\[’"‘\\\?abtnvfre]"
" hex and octal numbers
syn match   nasmCStringEscape  display contained "\\\(x\x\{2}\|\o\{1,3}\)"
" Unicode characters
syn match   nasmCStringEscape	display contained "\\\(u\x\{4}\|U\x\{8}\)"
" ISO C99 format strings (copied from cFormat in runtime/syntax/c.vim)
syn match   nasmCStringFormat	display "%\(\d\+\$\)\=[-+' #0*]*\(\d*\|\*\|\*\d\+\$\)\(\.\(\d*\|\*\|\*\d\+\$\)\)\=\([hlLjzt]\|ll\|hh\)\=\([aAbdiuoxXDOUfFeEgGcCsSpn]\|\[\^\=.[^]]*\]\)" contained
syn match   nasmCStringFormat	display "%%" contained
syn match   nasmString		+\("[^"]\{-}"\|'[^']\{-}'\)+
" Highlight C escape- and format-sequences within ``-strings
syn match   nasmCString	+\(`[^`]\{-}`\)+ contains=nasmCStringEscape,nasmCStringFormat extend
syn case ignore
syn match   nasmBinNumber	"\<\([01][01_]*[by]\|0[by][01_]\+\)\>"
syn match   nasmBinNumber	"\<\~\([01][01_]*[by]\|0[by][01_]\+\)\>"lc=1
syn match   nasmOctNumber	"\<\(\o[0-7_]*[qo]\|0[qo][0-7_]\+\)\>"
syn match   nasmOctNumber	"\<\~\(\o[0-7_]*[qo]\|0[qo][0-7_]\+\)\>"lc=1
syn match   nasmDecNumber	"\<\(\d[0-9_]*\|\d[0-9_]*d\|0d[0-9_]\+\)\>"
syn match   nasmDecNumber	"\<\~\(\d[0-9_]*\|\d[0-9_]*d\|0d[0-9_]\+\)\>"lc=1
syn match   nasmHexNumber	"\<\(\d[0-9a-f_]*h\|0[xh][0-9a-f_]\+\|\$\d[0-9a-f_]*\)\>"
syn match   nasmHexNumber	"\<\~\(\d[0-9a-f_]*h\|0[xh][0-9a-f_]\+\|\$\d[0-9a-f_]*\)\>"lc=1
syn match   nasmBinFloat	"\<\(0[by][01_]*\.[01_]*\(p[+-]\=[0-9_]*\)\=\)\|\(0[by][01_]*p[+-]\=[0-9_]*\)\>"
syn match   nasmOctFloat	"\<\(0[qo][0-7_]*\.[0-7_]*\(p[+-]\=[0-9_]*\)\=\)\|\(0[qo][0-7_]*p[+-]\=[0-9_]*\)\>"
syn match   nasmDecFloat	"\<\(\d[0-9_]*\.[0-9_]*\(e[+-]\=[0-9_]*\)\=\)\|\(\d[0-9_]*e[+-]\=[0-9_]*\)\>"
syn match   nasmHexFloat	"\<\(0[xh][0-9a-f_]\+\.[0-9a-f_]*\(p[+-]\=[0-9_]*\)\=\)\|\(0[xh][0-9a-f_]\+p[+-]\=[0-9_]*\)\>"
syn keyword nasmSpecFloat	Inf NaN SNaN QNaN __?Infinity?__ __?NaN?__ __?SNaN?__ __?QNaN?__
syn match   nasmBcdConst	"\<\(\d[0-9_]*p\|0p[0-9_]\+\)\>"
syn match   nasmNumberError	"\<\~\s*\d\+\.\d*\(e[+-]\=\d\+\)\=\>"


" Netwide Assembler Storage Directives:
"  Storage types
syn keyword nasmTypeError	DF EXTRN FWORD RESF TBYTE
syn keyword nasmType		FAR NEAR SHORT
syn keyword nasmType		BYTE WORD DWORD QWORD DQWORD HWORD DHWORD TWORD
syn keyword nasmType		CDECL FASTCALL NONE PASCAL STDCALL
syn keyword nasmStorage		DB DW DD DQ DT DO DY DZ
syn keyword nasmStorage		RESB RESW RESD RESQ REST RESO RESY RESZ
syn keyword nasmStorage		EXTERN GLOBAL COMMON
"  Structured storage types
syn match   nasmTypeError	"\<\(AT\|I\=\(END\)\=\(STRUCT\=\|UNION\)\|I\=END\)\>"
syn match   nasmStructureLabel	contained "\<\(AT\|I\=\(END\)\=\(STRUCT\=\|UNION\)\|I\=END\)\>"
"   structures cannot be nested (yet) -> use: 'keepend' and 're='
syn cluster nasmGrpCntnStruc	contains=ALLBUT,@nasmGrpInComments,nasmMacroDef,@nasmGrpInMacros,@nasmGrpInPreCondits,nasmStructureDef,@nasmGrpInStrucs
syn region  nasmStructureDef	transparent matchgroup=nasmStructure keepend start="^\s*STRUCT\>"hs=e-5 end="^\s*ENDSTRUCT\>"re=e-9 contains=@nasmGrpCntnStruc
syn region  nasmStructureDef	transparent matchgroup=nasmStructure keepend start="^\s*STRUC\>"hs=e-4  end="^\s*ENDSTRUC\>"re=e-8  contains=@nasmGrpCntnStruc
syn region  nasmStructureDef	transparent matchgroup=nasmStructure keepend start="\<ISTRUCT\=\>" end="\<IEND\(STRUCT\=\)\=\>" contains=@nasmGrpCntnStruc,nasmInStructure
"   union types are not part of nasm (yet)
"syn region  nasmStructureDef	transparent matchgroup=nasmStructure keepend start="^\s*UNION\>"hs=e-4 end="^\s*ENDUNION\>"re=e-8 contains=@nasmGrpCntnStruc
"syn region  nasmStructureDef	transparent matchgroup=nasmStructure keepend start="\<IUNION\>" end="\<IEND\(UNION\)\=\>" contains=@nasmGrpCntnStruc,nasmInStructure
syn match   nasmInStructure	contained "^\s*AT\>"hs=e-1
syn cluster nasmGrpInStrucs	contains=nasmStructure,nasmInStructure,nasmStructureLabel



" PreProcessor Instructions:
" NAsm PreProcs start with %, but % is not a character
syn match   nasmPreProcError	"%{\=\(%\=\k\+\|%%\+\k*\|[+-]\=\d\+\)}\="
if exists("nasm_loose_syntax")
  syn cluster nasmGrpNxtCtx	contains=nasmStructureLabel,nasmLabel,nasmLocalLabel,nasmSpecialLabel,nasmLabelError,nasmPreProcError
else
  syn cluster nasmGrpNxtCtx	contains=nasmStructureLabel,nasmLabel,nasmLabelError,nasmPreProcError
endif

"  Multi-line macro
syn cluster nasmGrpCntnMacro	contains=ALLBUT,@nasmGrpInComments,nasmStructureDef,@nasmGrpInStrucs,nasmMacroDef,@nasmGrpPreCondits,nasmMemReference,nasmInMacPreCondit,nasmInMacStrucDef
syn region  nasmMacroDef	matchgroup=nasmMacro keepend start="^\s*%macro\>"hs=e-5 start="^\s*%imacro\>"hs=e-6 end="^\s*%endmacro\>"re=e-9 contains=@nasmGrpCntnMacro,nasmInMacStrucDef
if exists("nasm_loose_syntax")
  syn match  nasmInMacLabel	contained "%\(%\k\+\>\|{%\k\+}\)"
  syn match  nasmInMacLabel	contained "%\($\+\(\w\|[#\.?@~]\)\k*\>\|{$\+\(\w\|[#\.?@~]\)\k*}\)"
  syn match  nasmInMacPreProc	contained "^\s*%\(push\|repl\)\>"hs=e-4 skipwhite nextgroup=nasmStructureLabel,nasmLabel,nasmInMacParam,nasmLocalLabel,nasmSpecialLabel,nasmLabelError,nasmPreProcError
  if !exists("nasm_no_warn")
    syn match nasmInMacLblWarn	contained "%\(%[$\.]\k*\>\|{%[$\.]\k*}\)"
    syn match nasmInMacLblWarn	contained "%\($\+\(\d\|[#\.@~]\)\k*\|{\$\+\(\d\|[#\.@~]\)\k*}\)"
    hi link nasmInMacCatLabel	nasmInMacLblWarn
  else
    hi link nasmInMacCatLabel	nasmInMacLabel
  endif
else
  syn match  nasmInMacLabel	contained "%\(%\(\w\|[#?@~]\)\k*\>\|{%\(\w\|[#?@~]\)\k*}\)"
  syn match  nasmInMacLabel	contained "%\($\+\(\h\|[?@]\)\k*\>\|{$\+\(\h\|[?@]\)\k*}\)"
  hi link nasmInMacCatLabel	nasmLabelError
endif
syn match   nasmInMacCatLabel	contained "\d\K\k*"lc=1
syn match   nasmInMacLabel	contained "\d}\k\+"lc=2
if !exists("nasm_no_warn")
  syn match  nasmInMacLblWarn	contained "%\(\($\+\|%\)[_~][._~]*\>\|{\($\+\|%\)[_~][._~]*}\)"
endif
syn match   nasmInMacPreProc	contained "^\s*%pop\>"hs=e-3
syn match   nasmInMacPreProc	contained "^\s*%\(push\|repl\)\>"hs=e-4 skipwhite nextgroup=@nasmGrpNxtCtx
"   structures cannot be nested (yet) -> use: 'keepend' and 're='
syn region  nasmInMacStrucDef	contained transparent matchgroup=nasmStructure keepend start="^\s*STRUCT\>"hs=e-5 end="^\s*ENDSTRUCT\>"re=e-9 contains=@nasmGrpCntnMacro
syn region  nasmInMacStrucDef	contained transparent matchgroup=nasmStructure keepend start="^\s*STRUC\>"hs=e-4  end="^\s*ENDSTRUC\>"re=e-8  contains=@nasmGrpCntnMacro
syn region  nasmInMacStrucDef	contained transparent matchgroup=nasmStructure keepend start="\<ISTRUCT\=\>" end="\<IEND\(STRUCT\=\)\=\>" contains=@nasmGrpCntnMacro,nasmInStructure
"   union types are not part of nasm (yet)
"syn region  nasmInMacStrucDef	contained transparent matchgroup=nasmStructure keepend start="^\s*UNION\>"hs=e-4 end="^\s*ENDUNION\>"re=e-8 contains=@nasmGrpCntnMacro
"syn region  nasmInMacStrucDef	contained transparent matchgroup=nasmStructure keepend start="\<IUNION\>" end="\<IEND\(UNION\)\=\>" contains=@nasmGrpCntnMacro,nasmInStructure
syn region  nasmInMacPreConDef	contained transparent matchgroup=nasmInMacPreCondit start="^\s*%ifnidni\>"hs=e-7 start="^\s*%if\(idni\|n\(ctx\|def\|idn\|num\|str\)\)\>"hs=e-6 start="^\s*%if\(ctx\|def\|idn\|nid\|num\|str\)\>"hs=e-5 start="^\s*%ifid\>"hs=e-4 start="^\s*%if\>"hs=e-2 end="%endif\>" contains=@nasmGrpCntnMacro,nasmInMacPreCondit,nasmInPreCondit
" Todo: allow STRUC/ISTRUC to be used inside preprocessor conditional block
syn match   nasmInMacPreCondit	contained transparent "ctx\s"lc=3 skipwhite nextgroup=@nasmGrpNxtCtx
syn match   nasmInMacPreCondit	contained "^\s*%elifctx\>"hs=e-7 skipwhite nextgroup=@nasmGrpNxtCtx
syn match   nasmInMacPreCondit	contained "^\s*%elifnctx\>"hs=e-8 skipwhite nextgroup=@nasmGrpNxtCtx
syn match   nasmInMacParamNum	contained "\<\d\+\.list\>"me=e-5
syn match   nasmInMacParamNum	contained "\<\d\+\.nolist\>"me=e-7
syn match   nasmInMacDirective	contained "\.\(no\)\=list\>"
syn match   nasmInMacMacro	contained transparent "macro\s"lc=5 skipwhite nextgroup=nasmStructureLabel
syn match   nasmInMacMacro	contained "^\s*%rotate\>"hs=e-6
syn match   nasmInMacParam	contained "%\([+-]\=\d\+\|{[+-]\=\d\+}\)"
"   nasm conditional macro operands/arguments
"   Todo: check feasebility; add too nasmGrpInMacros, etc.
"syn match   nasmInMacCond	contained "\<\(N\=\([ABGL]E\=\|[CEOSZ]\)\|P[EO]\=\)\>"
syn cluster nasmGrpInMacros	contains=nasmMacro,nasmInMacMacro,nasmInMacParam,nasmInMacParamNum,nasmInMacDirective,nasmInMacLabel,nasmInMacLblWarn,nasmInMacMemRef,nasmInMacPreConDef,nasmInMacPreCondit,nasmInMacPreProc,nasmInMacStrucDef

"   Context pre-procs that are better used inside a macro
if exists("nasm_ctx_outside_macro")
  syn region nasmPreConditDef	transparent matchgroup=nasmCtxPreCondit start="^\s*%ifnctx\>"hs=e-6 start="^\s*%ifctx\>"hs=e-5 end="%endif\>" contains=@nasmGrpCntnPreCon
  syn match  nasmCtxPreProc	"^\s*%pop\>"hs=e-3
  if exists("nasm_loose_syntax")
    syn match   nasmCtxLocLabel	"%$\+\(\w\|[#.?@~]\)\k*\>"
  else
    syn match   nasmCtxLocLabel	"%$\+\(\h\|[?@]\)\k*\>"
  endif
  syn match nasmCtxPreProc	"^\s*%\(push\|repl\)\>"hs=e-4 skipwhite nextgroup=@nasmGrpNxtCtx
  syn match nasmCtxPreCondit	contained transparent "ctx\s"lc=3 skipwhite nextgroup=@nasmGrpNxtCtx
  syn match nasmCtxPreCondit	contained "^\s*%elifctx\>"hs=e-7 skipwhite nextgroup=@nasmGrpNxtCtx
  syn match nasmCtxPreCondit	contained "^\s*%elifnctx\>"hs=e-8 skipwhite nextgroup=@nasmGrpNxtCtx
  if exists("nasm_no_warn")
    hi link nasmCtxPreCondit	nasmPreCondit
    hi link nasmCtxPreProc	nasmPreProc
    hi link nasmCtxLocLabel	nasmLocalLabel
  else
    hi link nasmCtxPreCondit	nasmPreProcWarn
    hi link nasmCtxPreProc	nasmPreProcWarn
    hi link nasmCtxLocLabel	nasmLabelWarn
  endif
endif

"  Conditional assembly
syn cluster nasmGrpCntnPreCon	contains=ALLBUT,@nasmGrpInComments,@nasmGrpInMacros,@nasmGrpInStrucs
syn region  nasmPreConditDef	transparent matchgroup=nasmPreCondit start="^\s*%ifnidni\>"hs=e-7 start="^\s*%if\(idni\|n\(def\|idn\|num\|str\)\)\>"hs=e-6 start="^\s*%if\(def\|idn\|nid\|num\|str\)\>"hs=e-5 start="^\s*%ifid\>"hs=e-4 start="^\s*%if\>"hs=e-2 end="%endif\>" contains=@nasmGrpCntnPreCon
syn match   nasmInPreCondit	contained "^\s*%el\(if\|se\)\>"hs=e-4
syn match   nasmInPreCondit	contained "^\s*%elifid\>"hs=e-6
syn match   nasmInPreCondit	contained "^\s*%elif\(def\|idn\|nid\|num\|str\)\>"hs=e-7
syn match   nasmInPreCondit	contained "^\s*%elif\(n\(def\|idn\|num\|str\)\|idni\)\>"hs=e-8
syn match   nasmInPreCondit	contained "^\s*%elifnidni\>"hs=e-9
syn cluster nasmGrpInPreCondits	contains=nasmPreCondit,nasmInPreCondit,nasmCtxPreCondit
syn cluster nasmGrpPreCondits	contains=nasmPreConditDef,@nasmGrpInPreCondits,nasmCtxPreProc,nasmCtxLocLabel

"  Other pre-processor statements
syn match   nasmPreProc		"^\s*%\(rep\|use\)\>"hs=e-3
syn match   nasmPreProc		"^\s*%line\>"hs=e-4
syn match   nasmPreProc		"^\s*%\(clear\|error\|fatal\)\>"hs=e-5
syn match   nasmPreProc		"^\s*%\(endrep\|strlen\|substr\)\>"hs=e-6
syn match   nasmPreProc		"^\s*%\(exitrep\|warning\)\>"hs=e-7
syn match   nasmDefine		"^\s*%undef\>"hs=e-5
syn match   nasmDefine		"^\s*%\(assign\|define\)\>"hs=e-6
syn match   nasmDefine		"^\s*%i\(assign\|define\)\>"hs=e-7
syn match   nasmDefine		"^\s*%unmacro\>"hs=e-7
syn match   nasmInclude		"^\s*%include\>"hs=e-7
" Todo: Treat the line tail after %fatal, %error, %warning as text

"  Multiple pre-processor instructions on single line detection (obsolete)
"syn match   nasmPreProcError	+^\s*\([^\t "%';][^"%';]*\|[^\t "';][^"%';]\+\)%\a\+\>+
syn cluster nasmGrpPreProcs	contains=nasmMacroDef,@nasmGrpInMacros,@nasmGrpPreCondits,nasmPreProc,nasmDefine,nasmInclude,nasmPreProcWarn,nasmPreProcError



" Register Identifiers:
"  Register operands:
syn match   nasmGen08Register	"\<[A-D][HL]\>"
syn match   nasmGen16Register	"\<\([A-D]X\|[DS]I\|[BS]P\)\>"
syn match   nasmGen32Register	"\<E\([A-D]X\|[DS]I\|[BS]P\)\>"
syn match   nasmGen64Register	"\<R\([A-D]X\|[DS]I\|[BS]P\|[89]\|1[0-5]\|[89][WDB]\|1[0-5][WDB]\)\>"
syn match   nasmExtRegister     "\<\([SB]PL\|[SD]IL\)\>"
syn match   nasmSegRegister	"\<[C-GS]S\>"
syn match   nasmSpcRegister	"\<E\=IP\>"
syn match   nasmFpuRegister	"\<ST\o\>"
syn match   nasmMmxRegister	"\<MM\o\>"
syn match   nasmAvxRegister	"\<[XYZ]MM\d\{1,2}\>"
syn match   nasmCtrlRegister	"\<CR\o\>"
syn match   nasmDebugRegister	"\<DR\o\>"
syn match   nasmTestRegister	"\<TR\o\>"
syn match   nasmRegisterError	"\<\(CR[15-9]\|DR[4-58-9]\|TR[0-28-9]\)\>"
syn match   nasmRegisterError	"\<[XYZ]MM\(3[2-9]\|[04-9]\d\)\>"
syn match   nasmRegisterError	"\<ST\((\d)\|[8-9]\>\)"
syn match   nasmRegisterError	"\<E\([A-D][HL]\|[C-GS]S\)\>"
"  Memory reference operand (address):
syn match   nasmMemRefError	"[[\]]"
syn cluster nasmGrpCntnMemRef	contains=ALLBUT,@nasmGrpComments,@nasmGrpPreProcs,@nasmGrpInStrucs,nasmMemReference,nasmMemRefError
syn match   nasmInMacMemRef	contained "\[[^;[\]]\{-}\]" contains=@nasmGrpCntnMemRef,nasmPreProcError,nasmInMacLabel,nasmInMacLblWarn,nasmInMacParam
syn match   nasmMemReference	"\[[^;[\]]\{-}\]" contains=@nasmGrpCntnMemRef,nasmPreProcError,nasmCtxLocLabel



" Netwide Assembler Directives:
"  Compilation constants
syn keyword nasmConstant	__BITS__ __DATE__ __FILE__ __FORMAT__ __LINE__
syn keyword nasmConstant	__NASM_MAJOR__ __NASM_MINOR__ __NASM_VERSION__
syn keyword nasmConstant	__TIME__
"  Instruction modifiers
syn match   nasmInstrModifier	"\(^\|:\)\s*[C-GS]S\>"ms=e-1
syn keyword nasmInstrModifier	A16 A32 O16 O32
syn match   nasmInstrModifier	"\<F\(ADD\|MUL\|\(DIV\|SUB\)R\=\)\s\+TO\>"lc=5,ms=e-1
"   the 'to' keyword is not allowed for fpu-pop instructions (yet)
"syn match   nasmInstrModifier	"\<F\(ADD\|MUL\|\(DIV\|SUB\)R\=\)P\s\+TO\>"lc=6,ms=e-1
"  NAsm directives
syn keyword nasmRepeat		TIMES
syn keyword nasmDirective	ALIGN[B] INCBIN EQU NOSPLIT SPLIT
syn keyword nasmDirective	ABSOLUTE BITS SECTION SEGMENT DEFAULT
syn keyword nasmDirective	ENDSECTION ENDSEGMENT
syn keyword nasmDirective	__SECT__
"  Macro created standard directives: (requires %include)
syn case match
syn keyword nasmStdDirective	ENDPROC EPILOGUE LOCALS PROC PROLOGUE USES
syn keyword nasmStdDirective	ENDIF ELSE ELIF ELSIF IF
"syn keyword nasmStdDirective	BREAK CASE DEFAULT ENDSWITCH SWITCH
"syn keyword nasmStdDirective	CASE OF ENDCASE
syn keyword nasmStdDirective	ENDFOR ENDWHILE FOR REPEAT UNTIL WHILE EXIT
syn case ignore
"  Format specific directives: (all formats)
"  (excluded: extension directives to section, global, common and extern)
syn keyword nasmFmtDirective	ORG
syn keyword nasmFmtDirective	EXPORT IMPORT GROUP UPPERCASE SEG WRT
syn keyword nasmFmtDirective	LIBRARY
syn case match
syn keyword nasmFmtDirective	_GLOBAL_OFFSET_TABLE_ __GLOBAL_OFFSET_TABLE_
syn keyword nasmFmtDirective	..start ..got ..gotoff ..gotpc ..plt ..sym
syn case ignore

" Instruction errors:
"  Instruction modifiers
syn match   nasmInstructnError	"\<TO\>"
" Standard Instructions:
syn match   nasmInstructnError	"\<\(F\=CMOV\|SET\|J\)N\=\a\{0,2}\>"
syn match   nasmInstructnError	"\<CMP\a\{0,2}XADD\>"
syn keyword nasmInstructnError	CMPS MOVS LCS LODS STOS XLAT
syn match   nasmInstructnError	"\<MOV\s[^,;[]*\<CS\>\s*[^:]"he=e-1
"  Input and Output
syn keyword nasmInstructnError	INS OUTS
"  Standard MMX instructions: (requires MMX1 unit)
syn match   nasmInstructnError	"\<P\(ADD\|SUB\)U\=S\=[DQ]\=\>"
syn match   nasmInstructnError	"\<PCMP\a\{0,2}[BDWQ]\=\>"
" Streaming SIMD Extension Packed Instructions: (requires SSE unit)
syn match   nasmInstructnError	"\<CMP\a\{1,5}[PS]S\>"
" AVX Instructions
syn match   nasmInstructnError  "\<VP\a\{3}R\a\>"


" Instructions:
" Standard
syn keyword nasmInstructionStandard AAA AAD AAM AAS ADC
syn keyword nasmInstructionStandard ADD AND ARPL 
syn keyword nasmInstructionStandard BOUND BSF BSR BSWAP BT
syn keyword nasmInstructionStandard BTC BTR BTS CALL CBW
syn keyword nasmInstructionStandard CDQ CDQE CLC CLD CLI
syn keyword nasmInstructionStandard CLTS CMC CMP CMPSB CMPSD
syn keyword nasmInstructionStandard CMPSQ CMPSW CMPXCHG CMPXCHG486 CMPXCHG8B
syn keyword nasmInstructionStandard CMPXCHG16B CPUID CQO
syn keyword nasmInstructionStandard CWD CWDE DAA DAS DEC
syn keyword nasmInstructionStandard DIV EMMS ENTER EQU
syn keyword nasmInstructionStandard F2XM1 FABS FADD FADDP FBLD
syn keyword nasmInstructionStandard FBSTP FCHS FCLEX FCMOVB FCMOVBE
syn keyword nasmInstructionStandard FCMOVE FCMOVNB FCMOVNBE FCMOVNE FCMOVNU
syn keyword nasmInstructionStandard FCMOVU FCOM FCOMI FCOMIP FCOMP
syn keyword nasmInstructionStandard FCOMPP FCOS FDECSTP FDISI FDIV
syn keyword nasmInstructionStandard FDIVP FDIVR FDIVRP FEMMS FENI
syn keyword nasmInstructionStandard FFREE FFREEP FIADD FICOM FICOMP
syn keyword nasmInstructionStandard FIDIV FIDIVR FILD FIMUL FINCSTP
syn keyword nasmInstructionStandard FINIT FIST FISTP FISTTP FISUB
syn keyword nasmInstructionStandard FISUBR FLD FLD1 FLDCW FLDENV
syn keyword nasmInstructionStandard FLDL2E FLDL2T FLDLG2 FLDLN2 FLDPI
syn keyword nasmInstructionStandard FLDZ FMUL FMULP FNCLEX FNDISI
syn keyword nasmInstructionStandard FNENI FNINIT FNOP FNSAVE FNSTCW
syn keyword nasmInstructionStandard FNSTENV FNSTSW FPATAN FPREM FPREM1
syn keyword nasmInstructionStandard FPTAN FRNDINT FRSTOR FSAVE FSCALE
syn keyword nasmInstructionStandard FSETPM FSIN FSINCOS FSQRT FST
syn keyword nasmInstructionStandard FSTCW FSTENV FSTP FSTSW FSUB
syn keyword nasmInstructionStandard FSUBP FSUBR FSUBRP FTST FUCOM
syn keyword nasmInstructionStandard FUCOMI FUCOMIP FUCOMP FUCOMPP FXAM
syn keyword nasmInstructionStandard FXCH FXTRACT FYL2X FYL2XP1 HLT
syn keyword nasmInstructionStandard IBTS ICEBP IDIV IMUL IN
syn keyword nasmInstructionStandard INC INSB INSD INSW INT
syn keyword nasmInstructionStandard INTO
syn keyword nasmInstructionStandard INVD INVPCID INVLPG INVLPGA IRET
syn keyword nasmInstructionStandard IRETD IRETQ IRETW JCXZ JECXZ
syn keyword nasmInstructionStandard JRCXZ JMP JMPE LAHF LAR
syn keyword nasmInstructionStandard LDS LEA LEAVE LES LFENCE
syn keyword nasmInstructionStandard LFS LGDT LGS LIDT LLDT
syn keyword nasmInstructionStandard LMSW LOADALL LOADALL286 LODSB LODSD
syn keyword nasmInstructionStandard LODSQ LODSW LOOP LOOPE LOOPNE
syn keyword nasmInstructionStandard LOOPNZ LOOPZ LSL LSS LTR
syn keyword nasmInstructionStandard MFENCE MONITOR MONITORX MOV MOVD
syn keyword nasmInstructionStandard MOVQ MOVSB MOVSD MOVSQ MOVSW
syn keyword nasmInstructionStandard MOVSX MOVSXD MOVSX MOVZX MUL
syn keyword nasmInstructionStandard MWAIT MWAITX NEG NOP NOT
syn keyword nasmInstructionStandard OR OUT OUTSB OUTSD OUTSW
syn keyword nasmInstructionStandard PACKSSDW PACKSSWB PACKUSWB PADDB PADDD
syn keyword nasmInstructionStandard PADDSB PADDSW PADDUSB PADDUSW
syn keyword nasmInstructionStandard PADDW PAND PANDN PAUSE 
syn keyword nasmInstructionStandard PAVGUSB PCMPEQB PCMPEQD PCMPEQW PCMPGTB
syn keyword nasmInstructionStandard PCMPGTD PCMPGTW PF2ID PFACC
syn keyword nasmInstructionStandard PFADD PFCMPEQ PFCMPGE PFCMPGT PFMAX
syn keyword nasmInstructionStandard PFMIN PFMUL PFRCP PFRCPIT1 PFRCPIT2
syn keyword nasmInstructionStandard PFRSQIT1 PFRSQRT PFSUB PFSUBR PI2FD
syn keyword nasmInstructionStandard PMADDWD PMULHRWA
syn keyword nasmInstructionStandard PMULHW PMULLW 
syn keyword nasmInstructionStandard POP POPA POPAD
syn keyword nasmInstructionStandard POPAW POPF POPFD POPFQ POPFW
syn keyword nasmInstructionStandard POR PREFETCH PREFETCHW PSLLD PSLLQ
syn keyword nasmInstructionStandard PSLLW PSRAD PSRAW PSRLD PSRLQ
syn keyword nasmInstructionStandard PSRLW PSUBB PSUBD PSUBSB 
syn keyword nasmInstructionStandard PSUBSW PSUBUSB PSUBUSW PSUBW PUNPCKHBW
syn keyword nasmInstructionStandard PUNPCKHDQ PUNPCKHWD PUNPCKLBW PUNPCKLDQ PUNPCKLWD
syn keyword nasmInstructionStandard PUSH PUSHA PUSHAD PUSHAW PUSHF
syn keyword nasmInstructionStandard PUSHFD PUSHFQ PUSHFW PXOR RCL
syn keyword nasmInstructionStandard RCR 
syn keyword nasmInstructionStandard RDTSCP RET RETF RETN RETW
syn keyword nasmInstructionStandard RETFW RETNW RETD RETFD RETND
syn keyword nasmInstructionStandard RETQ RETFQ RETNQ ROL ROR
syn keyword nasmInstructionStandard RSM RSTS
syn keyword nasmInstructionStandard SAHF SAL SALC SAR SBB
syn keyword nasmInstructionStandard SCASB SCASD SCASQ SCASW SFENCE
syn keyword nasmInstructionStandard SGDT SHL SHLD SHR SHRD
syn keyword nasmInstructionStandard SIDT SLDT SKINIT SMI 
syn keyword nasmInstructionStandard SMSW STC STD STI
syn keyword nasmInstructionStandard STOSB STOSD STOSQ STOSW STR
syn keyword nasmInstructionStandard SUB SWAPGS
syn keyword nasmInstructionStandard SYSCALL SYSENTER SYSEXIT SYSRET TEST
syn keyword nasmInstructionStandard UD0 UD1 UD2B UD2 UD2A
syn keyword nasmInstructionStandard UMOV VERR VERW FWAIT WBINVD
syn keyword nasmInstructionStandard XADD XBTS XCHG
syn keyword nasmInstructionStandard XLATB XLAT XOR CMOVA CMOVAE
syn keyword nasmInstructionStandard CMOVB CMOVBE CMOVC CMOVE CMOVG
syn keyword nasmInstructionStandard CMOVGE CMOVL CMOVLE CMOVNA CMOVNAE
syn keyword nasmInstructionStandard CMOVNB CMOVNBE CMOVNC CMOVNE CMOVNG
syn keyword nasmInstructionStandard CMOVNGE CMOVNL CMOVNLE CMOVNO CMOVNP
syn keyword nasmInstructionStandard CMOVNS CMOVNZ CMOVO CMOVP CMOVPE
syn keyword nasmInstructionStandard CMOVPO CMOVS CMOVZ JA JAE
syn keyword nasmInstructionStandard JB JBE JC JCXZ JE
syn keyword nasmInstructionStandard JECXZ JG JGE JL JLE
syn keyword nasmInstructionStandard JNA JNAE JNB JNBE JNC
syn keyword nasmInstructionStandard JNE JNG JNGE JNL JNLE
syn keyword nasmInstructionStandard JNO JNP JNS JNZ JO
syn keyword nasmInstructionStandard JP JPE JPO JRCXZ JS
syn keyword nasmInstructionStandard JZ SETA SETAE SETB SETBE
syn keyword nasmInstructionStandard SETC SETE SETG SETGE SETL
syn keyword nasmInstructionStandard SETLE SETNA SETNAE SETNB SETNBE
syn keyword nasmInstructionStandard SETNC SETNE SETNG SETNGE SETNL
syn keyword nasmInstructionStandard SETNLE SETNO SETNP SETNS SETNZ
syn keyword nasmInstructionStandard SETO SETP SETPE SETPO SETS
syn keyword nasmInstructionStandard SETZ 
" SIMD
syn keyword nasmInstructionSIMD ADDPS ADDSS ANDNPS ANDPS CMPEQPS
syn keyword nasmInstructionSIMD CMPEQSS CMPLEPS CMPLESS CMPLTPS CMPLTSS
syn keyword nasmInstructionSIMD CMPNEQPS CMPNEQSS CMPNLEPS CMPNLESS CMPNLTPS
syn keyword nasmInstructionSIMD CMPNLTSS CMPORDPS CMPORDSS CMPUNORDPS CMPUNORDSS
syn keyword nasmInstructionSIMD CMPPS CMPSS COMISS CVTPI2PS CVTPS2PI
syn keyword nasmInstructionSIMD CVTSI2SS CVTSS2SI CVTTPS2PI CVTTSS2SI DIVPS
syn keyword nasmInstructionSIMD DIVSS LDMXCSR MAXPS MAXSS MINPS
syn keyword nasmInstructionSIMD MINSS MOVAPS MOVHPS MOVLHPS MOVLPS
syn keyword nasmInstructionSIMD MOVHLPS MOVMSKPS MOVNTPS MOVSS MOVUPS
syn keyword nasmInstructionSIMD MULPS MULSS ORPS RCPPS RCPSS
syn keyword nasmInstructionSIMD RSQRTPS RSQRTSS SHUFPS SQRTPS SQRTSS
syn keyword nasmInstructionSIMD STMXCSR SUBPS SUBSS UCOMISS UNPCKHPS
syn keyword nasmInstructionSIMD UNPCKLPS XORPS
" SSE
syn keyword nasmInstructionSSE FXRSTOR FXRSTOR64 FXSAVE FXSAVE64
" XSAVE
syn keyword nasmInstructionXSAVE XGETBV XSETBV XSAVE XSAVE64 XSAVEC
syn keyword nasmInstructionXSAVE XSAVEC64 XSAVEOPT XSAVEOPT64 XSAVES XSAVES64
syn keyword nasmInstructionXSAVE XRSTOR XRSTOR64 XRSTORS XRSTORS64
" MEM
syn keyword nasmInstructionMEM PREFETCHNTA PREFETCHT0 PREFETCHT1 PREFETCHT2 PREFETCHIT0
syn keyword nasmInstructionMEM PREFETCHIT1 SFENCE
" MMX
syn keyword nasmInstructionMMX MASKMOVQ MOVNTQ PAVGB PAVGW PEXTRW
syn keyword nasmInstructionMMX PINSRW PMAXSW PMAXUB PMINSW PMINUB
syn keyword nasmInstructionMMX PMOVMSKB PMULHUW PSADBW PSHUFW
" 3DNOW
syn keyword nasmInstruction3DNOW PF2IW PFNACC PFPNACC PI2FW PSWAPD
" SSE2
syn keyword nasmInstructionSSE2 MASKMOVDQU CLFLUSH MOVNTDQ MOVNTI MOVNTPD
syn keyword nasmInstructionSSE2 LFENCE MFENCE
" WMMX
syn keyword nasmInstructionWMMX MOVD MOVDQA MOVDQU MOVDQ2Q MOVQ
syn keyword nasmInstructionWMMX MOVQ2DQ PACKSSWB PACKSSDW PACKUSWB PADDB
syn keyword nasmInstructionWMMX PADDW PADDD PADDQ PADDSB PADDSW
syn keyword nasmInstructionWMMX PADDUSB PADDUSW PAND PANDN PAVGB
syn keyword nasmInstructionWMMX PAVGW PCMPEQB PCMPEQW PCMPEQD PCMPGTB
syn keyword nasmInstructionWMMX PCMPGTW PCMPGTD PEXTRW PINSRW PMADDWD
syn keyword nasmInstructionWMMX PMAXSW PMAXUB PMINSW PMINUB PMOVMSKB
syn keyword nasmInstructionWMMX PMULHUW PMULHW PMULLW PMULUDQ POR
syn keyword nasmInstructionWMMX PSADBW PSHUFD PSHUFHW PSHUFLW PSLLDQ
syn keyword nasmInstructionWMMX PSLLW PSLLD PSLLQ PSRAW PSRAD
syn keyword nasmInstructionWMMX PSRLDQ PSRLW PSRLD PSRLQ PSUBB
syn keyword nasmInstructionWMMX PSUBW PSUBD PSUBQ PSUBSB PSUBSW
syn keyword nasmInstructionWMMX PSUBUSB PSUBUSW PUNPCKHBW PUNPCKHWD PUNPCKHDQ
syn keyword nasmInstructionWMMX PUNPCKHQDQ PUNPCKLBW PUNPCKLWD PUNPCKLDQ PUNPCKLQDQ
syn keyword nasmInstructionWMMX PXOR
" WSSD
syn keyword nasmInstructionWSSD ADDPD ADDSD ANDNPD ANDPD CMPEQPD
syn keyword nasmInstructionWSSD CMPEQSD CMPLEPD CMPLESD CMPLTPD CMPLTSD
syn keyword nasmInstructionWSSD CMPNEQPD CMPNEQSD CMPNLEPD CMPNLESD CMPNLTPD
syn keyword nasmInstructionWSSD CMPNLTSD CMPORDPD CMPORDSD CMPUNORDPD CMPUNORDSD
syn keyword nasmInstructionWSSD CMPPD CMPSD COMISD CVTDQ2PD CVTDQ2PS
syn keyword nasmInstructionWSSD CVTPD2DQ CVTPD2PI CVTPD2PS CVTPI2PD CVTPS2DQ
syn keyword nasmInstructionWSSD CVTPS2PD CVTSD2SI CVTSD2SS CVTSI2SD CVTSS2SD
syn keyword nasmInstructionWSSD CVTTPD2PI CVTTPD2DQ CVTTPS2DQ CVTTSD2SI DIVPD
syn keyword nasmInstructionWSSD DIVSD MAXPD MAXSD MINPD MINSD
syn keyword nasmInstructionWSSD MOVAPD MOVHPD MOVLPD MOVMSKPD MOVSD
syn keyword nasmInstructionWSSD MOVUPD MULPD MULSD ORPD SHUFPD
syn keyword nasmInstructionWSSD SQRTPD SQRTSD SUBPD SUBSD UCOMISD
syn keyword nasmInstructionWSSD UNPCKHPD UNPCKLPD XORPD
" PRESSCOT
syn keyword nasmInstructionPRESSCOT ADDSUBPD ADDSUBPS HADDPD HADDPS HSUBPD
syn keyword nasmInstructionPRESSCOT HSUBPS LDDQU MOVDDUP MOVSHDUP MOVSLDUP
" VMXSVM
syn keyword nasmInstructionVMXSVM CLGI STGI VMCALL VMCLEAR VMFUNC
syn keyword nasmInstructionVMXSVM VMLAUNCH VMLOAD VMMCALL VMPTRLD VMPTRST
syn keyword nasmInstructionVMXSVM VMREAD VMRESUME VMRUN VMSAVE VMWRITE
syn keyword nasmInstructionVMXSVM VMXOFF VMXON
" PTVMX
syn keyword nasmInstructionPTVMX INVEPT INVVPID
" SEVSNPAMD
syn keyword nasmInstructionSEVSNPAMD PVALIDATE RMPADJUST VMGEXIT
" TEJAS
syn keyword nasmInstructionTEJAS PABSB PABSW PABSD PALIGNR PHADDW
syn keyword nasmInstructionTEJAS PHADDD PHADDSW PHSUBW PHSUBD PHSUBSW
syn keyword nasmInstructionTEJAS PMADDUBSW PMULHRSW PSHUFB PSIGNB PSIGNW
syn keyword nasmInstructionTEJAS PSIGND
" AMD_SSE4A
syn keyword nasmInstructionAMD_SSE4A EXTRQ INSERTQ MOVNTSD MOVNTSS
" BARCELONA
syn keyword nasmInstructionBARCELONA LZCNT 
" PENRY
syn keyword nasmInstructionPENRY BLENDPD BLENDPS BLENDVPD BLENDVPS DPPD
syn keyword nasmInstructionPENRY DPPS EXTRACTPS INSERTPS MOVNTDQA MPSADBW
syn keyword nasmInstructionPENRY PACKUSDW PBLENDVB PBLENDW PCMPEQQ PEXTRB
syn keyword nasmInstructionPENRY PEXTRD PEXTRQ PEXTRW PHMINPOSUW PINSRB
syn keyword nasmInstructionPENRY PINSRD PINSRQ PMAXSB PMAXSD PMAXUD
syn keyword nasmInstructionPENRY PMAXUW PMINSB PMINSD PMINUD PMINUW
syn keyword nasmInstructionPENRY PMOVSXBW PMOVSXBD PMOVSXBQ PMOVSXWD PMOVSXWQ
syn keyword nasmInstructionPENRY PMOVSXDQ PMOVZXBW PMOVZXBD PMOVZXBQ PMOVZXWD
syn keyword nasmInstructionPENRY PMOVZXWQ PMOVZXDQ PMULDQ PMULLD PTEST
syn keyword nasmInstructionPENRY ROUNDPD ROUNDPS ROUNDSD ROUNDSS
" NEHALEM
syn keyword nasmInstructionNEHALEM CRC32 PCMPESTRI PCMPESTRM PCMPISTRI PCMPISTRM
syn keyword nasmInstructionNEHALEM PCMPGTQ POPCNT
" SMX
syn keyword nasmInstructionSMX GETSEC 
" GEODE_3DNOW
syn keyword nasmInstructionGEODE_3DNOW PFRCPV PFRSQRTV
" INTEL_NEW
syn keyword nasmInstructionINTEL_NEW MOVBE 
" AES
syn keyword nasmInstructionAES AESENC AESENCLAST AESDEC AESDECLAST AESIMC
syn keyword nasmInstructionAES AESKEYGENASSIST
" AVX_AES
syn keyword nasmInstructionAVX_AES VAESENC VAESENCLAST VAESDEC VAESDECLAST VAESIMC
syn keyword nasmInstructionAVX_AES VAESKEYGENASSIST
" INTEL_PUB
syn keyword nasmInstructionINTEL_PUB VAESENC VAESENCLAST VAESDEC VAESDECLAST VAESENC
syn keyword nasmInstructionINTEL_PUB VAESENCLAST VAESDEC VAESDECLAST VAESENC VAESENCLAST
syn keyword nasmInstructionINTEL_PUB VAESDEC VAESDECLAST
" AVX
syn keyword nasmInstructionAVX VADDPD VADDPS VADDSD VADDSS VADDSUBPD
syn keyword nasmInstructionAVX VADDSUBPS VANDPD VANDPS VANDNPD VANDNPS
syn keyword nasmInstructionAVX VBLENDPD VBLENDPS VBLENDVPD VBLENDVPS VBROADCASTSS
syn keyword nasmInstructionAVX VBROADCASTSD VBROADCASTF128 VCMPEQ_OSPD VCMPEQPD VCMPLT_OSPD
syn keyword nasmInstructionAVX VCMPLTPD VCMPLE_OSPD VCMPLEPD VCMPUNORD_QPD VCMPUNORDPD
syn keyword nasmInstructionAVX VCMPNEQ_UQPD VCMPNEQPD VCMPNLT_USPD VCMPNLTPD VCMPNLE_USPD
syn keyword nasmInstructionAVX VCMPNLEPD VCMPORD_QPD VCMPORDPD VCMPEQ_UQPD VCMPNGE_USPD
syn keyword nasmInstructionAVX VCMPNGEPD VCMPNGT_USPD VCMPNGTPD VCMPFALSE_OQPD VCMPFALSEPD
syn keyword nasmInstructionAVX VCMPNEQ_OQPD VCMPGE_OSPD VCMPGEPD VCMPGT_OSPD VCMPGTPD
syn keyword nasmInstructionAVX VCMPTRUE_UQPD VCMPTRUEPD VCMPEQ_OSPD VCMPLT_OQPD VCMPLE_OQPD
syn keyword nasmInstructionAVX VCMPUNORD_SPD VCMPNEQ_USPD VCMPNLT_UQPD VCMPNLE_UQPD VCMPORD_SPD
syn keyword nasmInstructionAVX VCMPEQ_USPD VCMPNGE_UQPD VCMPNGT_UQPD VCMPFALSE_OSPD VCMPNEQ_OSPD
syn keyword nasmInstructionAVX VCMPGE_OQPD VCMPGT_OQPD VCMPTRUE_USPD VCMPPD VCMPEQ_OSPS
syn keyword nasmInstructionAVX VCMPEQPS VCMPLT_OSPS VCMPLTPS VCMPLE_OSPS VCMPLEPS
syn keyword nasmInstructionAVX VCMPUNORD_QPS VCMPUNORDPS VCMPNEQ_UQPS VCMPNEQPS VCMPNLT_USPS
syn keyword nasmInstructionAVX VCMPNLTPS VCMPNLE_USPS VCMPNLEPS VCMPORD_QPS VCMPORDPS
syn keyword nasmInstructionAVX VCMPEQ_UQPS VCMPNGE_USPS VCMPNGEPS VCMPNGT_USPS VCMPNGTPS
syn keyword nasmInstructionAVX VCMPFALSE_OQPS VCMPFALSEPS VCMPNEQ_OQPS VCMPGE_OSPS VCMPGEPS
syn keyword nasmInstructionAVX VCMPGT_OSPS VCMPGTPS VCMPTRUE_UQPS VCMPTRUEPS VCMPEQ_OSPS
syn keyword nasmInstructionAVX VCMPLT_OQPS VCMPLE_OQPS VCMPUNORD_SPS VCMPNEQ_USPS VCMPNLT_UQPS
syn keyword nasmInstructionAVX VCMPNLE_UQPS VCMPORD_SPS VCMPEQ_USPS VCMPNGE_UQPS VCMPNGT_UQPS
syn keyword nasmInstructionAVX VCMPFALSE_OSPS VCMPNEQ_OSPS VCMPGE_OQPS VCMPGT_OQPS VCMPTRUE_USPS
syn keyword nasmInstructionAVX VCMPPS VCMPEQ_OSSD VCMPEQSD VCMPLT_OSSD VCMPLTSD
syn keyword nasmInstructionAVX VCMPLE_OSSD VCMPLESD VCMPUNORD_QSD VCMPUNORDSD VCMPNEQ_UQSD
syn keyword nasmInstructionAVX VCMPNEQSD VCMPNLT_USSD VCMPNLTSD VCMPNLE_USSD VCMPNLESD
syn keyword nasmInstructionAVX VCMPORD_QSD VCMPORDSD VCMPEQ_UQSD VCMPNGE_USSD VCMPNGESD
syn keyword nasmInstructionAVX VCMPNGT_USSD VCMPNGTSD VCMPFALSE_OQSD VCMPFALSESD VCMPNEQ_OQSD
syn keyword nasmInstructionAVX VCMPGE_OSSD VCMPGESD VCMPGT_OSSD VCMPGTSD VCMPTRUE_UQSD
syn keyword nasmInstructionAVX VCMPTRUESD VCMPEQ_OSSD VCMPLT_OQSD VCMPLE_OQSD VCMPUNORD_SSD
syn keyword nasmInstructionAVX VCMPNEQ_USSD VCMPNLT_UQSD VCMPNLE_UQSD VCMPORD_SSD VCMPEQ_USSD
syn keyword nasmInstructionAVX VCMPNGE_UQSD VCMPNGT_UQSD VCMPFALSE_OSSD VCMPNEQ_OSSD VCMPGE_OQSD
syn keyword nasmInstructionAVX VCMPGT_OQSD VCMPTRUE_USSD VCMPSD VCMPEQ_OSSS VCMPEQSS
syn keyword nasmInstructionAVX VCMPLT_OSSS VCMPLTSS VCMPLE_OSSS VCMPLESS VCMPUNORD_QSS
syn keyword nasmInstructionAVX VCMPUNORDSS VCMPNEQ_UQSS VCMPNEQSS VCMPNLT_USSS VCMPNLTSS
syn keyword nasmInstructionAVX VCMPNLE_USSS VCMPNLESS VCMPORD_QSS VCMPORDSS VCMPEQ_UQSS
syn keyword nasmInstructionAVX VCMPNGE_USSS VCMPNGESS VCMPNGT_USSS VCMPNGTSS VCMPFALSE_OQSS
syn keyword nasmInstructionAVX VCMPFALSESS VCMPNEQ_OQSS VCMPGE_OSSS VCMPGESS VCMPGT_OSSS
syn keyword nasmInstructionAVX VCMPGTSS VCMPTRUE_UQSS VCMPTRUESS VCMPEQ_OSSS VCMPLT_OQSS
syn keyword nasmInstructionAVX VCMPLE_OQSS VCMPUNORD_SSS VCMPNEQ_USSS VCMPNLT_UQSS VCMPNLE_UQSS
syn keyword nasmInstructionAVX VCMPORD_SSS VCMPEQ_USSS VCMPNGE_UQSS VCMPNGT_UQSS VCMPFALSE_OSSS
syn keyword nasmInstructionAVX VCMPNEQ_OSSS VCMPGE_OQSS VCMPGT_OQSS VCMPTRUE_USSS VCMPSS
syn keyword nasmInstructionAVX VCOMISD VCOMISS VCVTDQ2PD VCVTDQ2PS VCVTPD2DQ
syn keyword nasmInstructionAVX VCVTPD2PS VCVTPS2DQ VCVTPS2PD VCVTSD2SI VCVTSD2SS
syn keyword nasmInstructionAVX VCVTSI2SD VCVTSI2SS VCVTSS2SD VCVTSS2SI VCVTTPD2DQ
syn keyword nasmInstructionAVX VCVTTPS2DQ VCVTTSD2SI VCVTTSS2SI VDIVPD VDIVPS
syn keyword nasmInstructionAVX VDIVSD VDIVSS VDPPD VDPPS VEXTRACTF128
syn keyword nasmInstructionAVX VEXTRACTPS VHADDPD VHADDPS VHSUBPD VHSUBPS
syn keyword nasmInstructionAVX VINSERTF128 VINSERTPS VLDDQU VLDQQU VLDDQU
syn keyword nasmInstructionAVX VLDMXCSR VMASKMOVDQU VMASKMOVPS VMASKMOVPD VMAXPD
syn keyword nasmInstructionAVX VMAXPS VMAXSD VMAXSS VMINPD VMINPS
syn keyword nasmInstructionAVX VMINSD VMINSS VMOVAPD VMOVAPS VMOVD
syn keyword nasmInstructionAVX VMOVQ VMOVDDUP VMOVDQA VMOVQQA VMOVDQA
syn keyword nasmInstructionAVX VMOVDQU VMOVQQU VMOVDQU VMOVHLPS VMOVHPD
syn keyword nasmInstructionAVX VMOVHPS VMOVLHPS VMOVLPD VMOVLPS VMOVMSKPD
syn keyword nasmInstructionAVX VMOVMSKPS VMOVNTDQ VMOVNTQQ VMOVNTDQ VMOVNTDQA
syn keyword nasmInstructionAVX VMOVNTPD VMOVNTPS VMOVSD VMOVSHDUP VMOVSLDUP
syn keyword nasmInstructionAVX VMOVSS VMOVUPD VMOVUPS VMPSADBW VMULPD
syn keyword nasmInstructionAVX VMULPS VMULSD VMULSS VORPD VORPS
syn keyword nasmInstructionAVX VPABSB VPABSW VPABSD VPACKSSWB VPACKSSDW
syn keyword nasmInstructionAVX VPACKUSWB VPACKUSDW VPADDB VPADDW VPADDD
syn keyword nasmInstructionAVX VPADDQ VPADDSB VPADDSW VPADDUSB VPADDUSW
syn keyword nasmInstructionAVX VPALIGNR VPAND VPANDN VPAVGB VPAVGW
syn keyword nasmInstructionAVX VPBLENDVB VPBLENDW VPCMPESTRI VPCMPESTRM VPCMPISTRI
syn keyword nasmInstructionAVX VPCMPISTRM VPCMPEQB VPCMPEQW VPCMPEQD VPCMPEQQ
syn keyword nasmInstructionAVX VPCMPGTB VPCMPGTW VPCMPGTD VPCMPGTQ VPERMILPD
syn keyword nasmInstructionAVX VPERMILPS VPERM2F128 VPEXTRB VPEXTRW VPEXTRD
syn keyword nasmInstructionAVX VPEXTRQ VPHADDW VPHADDD VPHADDSW VPHMINPOSUW
syn keyword nasmInstructionAVX VPHSUBW VPHSUBD VPHSUBSW VPINSRB VPINSRW
syn keyword nasmInstructionAVX VPINSRD VPINSRQ VPMADDWD VPMADDUBSW VPMAXSB
syn keyword nasmInstructionAVX VPMAXSW VPMAXSD VPMAXUB VPMAXUW VPMAXUD
syn keyword nasmInstructionAVX VPMINSB VPMINSW VPMINSD VPMINUB VPMINUW
syn keyword nasmInstructionAVX VPMINUD VPMOVMSKB VPMOVSXBW VPMOVSXBD VPMOVSXBQ
syn keyword nasmInstructionAVX VPMOVSXWD VPMOVSXWQ VPMOVSXDQ VPMOVZXBW VPMOVZXBD
syn keyword nasmInstructionAVX VPMOVZXBQ VPMOVZXWD VPMOVZXWQ VPMOVZXDQ VPMULHUW
syn keyword nasmInstructionAVX VPMULHRSW VPMULHW VPMULLW VPMULLD VPMULUDQ
syn keyword nasmInstructionAVX VPMULDQ VPOR VPSADBW VPSHUFB VPSHUFD
syn keyword nasmInstructionAVX VPSHUFHW VPSHUFLW VPSIGNB VPSIGNW VPSIGND
syn keyword nasmInstructionAVX VPSLLDQ VPSRLDQ VPSLLW VPSLLD VPSLLQ
syn keyword nasmInstructionAVX VPSRAW VPSRAD VPSRLW VPSRLD VPSRLQ
syn keyword nasmInstructionAVX VPTEST VPSUBB VPSUBW VPSUBD VPSUBQ
syn keyword nasmInstructionAVX VPSUBSB VPSUBSW VPSUBUSB VPSUBUSW VPUNPCKHBW
syn keyword nasmInstructionAVX VPUNPCKHWD VPUNPCKHDQ VPUNPCKHQDQ VPUNPCKLBW VPUNPCKLWD
syn keyword nasmInstructionAVX VPUNPCKLDQ VPUNPCKLQDQ VPXOR VRCPPS VRCPSS
syn keyword nasmInstructionAVX VRSQRTPS VRSQRTSS VROUNDPD VROUNDPS VROUNDSD
syn keyword nasmInstructionAVX VROUNDSS VSHUFPD VSHUFPS VSQRTPD VSQRTPS
syn keyword nasmInstructionAVX VSQRTSD VSQRTSS VSTMXCSR VSUBPD VSUBPS
syn keyword nasmInstructionAVX VSUBSD VSUBSS VTESTPS VTESTPD VUCOMISD
syn keyword nasmInstructionAVX VUCOMISS VUNPCKHPD VUNPCKHPS VUNPCKLPD VUNPCKLPS
syn keyword nasmInstructionAVX VXORPD VXORPS VZEROALL VZEROUPPER
" INTEL_CMUL
syn keyword nasmInstructionINTEL_CMUL PCLMULLQLQDQ PCLMULHQLQDQ PCLMULLQHQDQ PCLMULHQHQDQ PCLMULQDQ
" INTEL_AVX_CMUL
syn keyword nasmInstructionINTEL_AVX_CMUL VPCLMULLQLQDQ VPCLMULHQLQDQ VPCLMULLQHQDQ VPCLMULHQHQDQ VPCLMULQDQ
syn keyword nasmInstructionINTEL_AVX_CMUL VPCLMULLQLQDQ VPCLMULHQLQDQ VPCLMULLQHQDQ VPCLMULHQHQDQ VPCLMULQDQ
syn keyword nasmInstructionINTEL_AVX_CMUL VPCLMULLQLQDQ VPCLMULHQLQDQ VPCLMULLQHQDQ VPCLMULHQHQDQ VPCLMULQDQ
syn keyword nasmInstructionINTEL_AVX_CMUL VPCLMULLQLQDQ VPCLMULHQLQDQ VPCLMULLQHQDQ VPCLMULHQHQDQ VPCLMULQDQ
syn keyword nasmInstructionINTEL_AVX_CMUL VPCLMULLQLQDQ VPCLMULHQLQDQ VPCLMULLQHQDQ VPCLMULHQHQDQ VPCLMULQDQ
" INTEL_FMA
syn keyword nasmInstructionINTEL_FMA VFMADD132PS VFMADD132PD VFMADD312PS VFMADD312PD VFMADD213PS
syn keyword nasmInstructionINTEL_FMA VFMADD213PD VFMADD123PS VFMADD123PD VFMADD231PS VFMADD231PD
syn keyword nasmInstructionINTEL_FMA VFMADD321PS VFMADD321PD VFMADDSUB132PS VFMADDSUB132PD VFMADDSUB312PS
syn keyword nasmInstructionINTEL_FMA VFMADDSUB312PD VFMADDSUB213PS VFMADDSUB213PD VFMADDSUB123PS VFMADDSUB123PD
syn keyword nasmInstructionINTEL_FMA VFMADDSUB231PS VFMADDSUB231PD VFMADDSUB321PS VFMADDSUB321PD VFMSUB132PS
syn keyword nasmInstructionINTEL_FMA VFMSUB132PD VFMSUB312PS VFMSUB312PD VFMSUB213PS VFMSUB213PD
syn keyword nasmInstructionINTEL_FMA VFMSUB123PS VFMSUB123PD VFMSUB231PS VFMSUB231PD VFMSUB321PS
syn keyword nasmInstructionINTEL_FMA VFMSUB321PD VFMSUBADD132PS VFMSUBADD132PD VFMSUBADD312PS VFMSUBADD312PD
syn keyword nasmInstructionINTEL_FMA VFMSUBADD213PS VFMSUBADD213PD VFMSUBADD123PS VFMSUBADD123PD VFMSUBADD231PS
syn keyword nasmInstructionINTEL_FMA VFMSUBADD231PD VFMSUBADD321PS VFMSUBADD321PD VFNMADD132PS VFNMADD132PD
syn keyword nasmInstructionINTEL_FMA VFNMADD312PS VFNMADD312PD VFNMADD213PS VFNMADD213PD VFNMADD123PS
syn keyword nasmInstructionINTEL_FMA VFNMADD123PD VFNMADD231PS VFNMADD231PD VFNMADD321PS VFNMADD321PD
syn keyword nasmInstructionINTEL_FMA VFNMSUB132PS VFNMSUB132PD VFNMSUB312PS VFNMSUB312PD VFNMSUB213PS
syn keyword nasmInstructionINTEL_FMA VFNMSUB213PD VFNMSUB123PS VFNMSUB123PD VFNMSUB231PS VFNMSUB231PD
syn keyword nasmInstructionINTEL_FMA VFNMSUB321PS VFNMSUB321PD VFMADD132SS VFMADD132SD VFMADD312SS
syn keyword nasmInstructionINTEL_FMA VFMADD312SD VFMADD213SS VFMADD213SD VFMADD123SS VFMADD123SD
syn keyword nasmInstructionINTEL_FMA VFMADD231SS VFMADD231SD VFMADD321SS VFMADD321SD VFMSUB132SS
syn keyword nasmInstructionINTEL_FMA VFMSUB132SD VFMSUB312SS VFMSUB312SD VFMSUB213SS VFMSUB213SD
syn keyword nasmInstructionINTEL_FMA VFMSUB123SS VFMSUB123SD VFMSUB231SS VFMSUB231SD VFMSUB321SS
syn keyword nasmInstructionINTEL_FMA VFMSUB321SD VFNMADD132SS VFNMADD132SD VFNMADD312SS VFNMADD312SD
syn keyword nasmInstructionINTEL_FMA VFNMADD213SS VFNMADD213SD VFNMADD123SS VFNMADD123SD VFNMADD231SS
syn keyword nasmInstructionINTEL_FMA VFNMADD231SD VFNMADD321SS VFNMADD321SD VFNMSUB132SS VFNMSUB132SD
syn keyword nasmInstructionINTEL_FMA VFNMSUB312SS VFNMSUB312SD VFNMSUB213SS VFNMSUB213SD VFNMSUB123SS
syn keyword nasmInstructionINTEL_FMA VFNMSUB123SD VFNMSUB231SS VFNMSUB231SD VFNMSUB321SS VFNMSUB321SD
" INTEL_POST32
syn keyword nasmInstructionINTEL_POST32 RDFSBASE RDGSBASE RDRAND WRFSBASE WRGSBASE
syn keyword nasmInstructionINTEL_POST32 VCVTPH2PS VCVTPS2PH ADCX ADOX RDSEED
" SUPERVISOR
syn keyword nasmInstructionSUPERVISOR CLAC STAC
" VIA_SECURITY
syn keyword nasmInstructionVIA_SECURITY XSTORE XCRYPTECB XCRYPTCBC XCRYPTCTR XCRYPTCFB
syn keyword nasmInstructionVIA_SECURITY XCRYPTOFB MONTMUL XSHA1 XSHA256
" AMD_PROFILING
syn keyword nasmInstructionAMD_PROFILING LLWPCB SLWPCB LWPVAL LWPINS
" XOP_FMA4
syn keyword nasmInstructionXOP_FMA4 VFMADDPD VFMADDPS VFMADDSD VFMADDSS VFMADDSUBPD
syn keyword nasmInstructionXOP_FMA4 VFMADDSUBPS VFMSUBADDPD VFMSUBADDPS VFMSUBPD VFMSUBPS
syn keyword nasmInstructionXOP_FMA4 VFMSUBSD VFMSUBSS VFNMADDPD VFNMADDPS VFNMADDSD
syn keyword nasmInstructionXOP_FMA4 VFNMADDSS VFNMSUBPD VFNMSUBPS VFNMSUBSD VFNMSUBSS
syn keyword nasmInstructionXOP_FMA4 VFRCZPD VFRCZPS VFRCZSD VFRCZSS VPCMOV
syn keyword nasmInstructionXOP_FMA4 VPCOMB VPCOMD VPCOMQ VPCOMUB VPCOMUD
syn keyword nasmInstructionXOP_FMA4 VPCOMUQ VPCOMUW VPCOMW VPHADDBD VPHADDBQ
syn keyword nasmInstructionXOP_FMA4 VPHADDBW VPHADDDQ VPHADDUBD VPHADDUBQ VPHADDUBW
syn keyword nasmInstructionXOP_FMA4 VPHADDUDQ VPHADDUWD VPHADDUWQ VPHADDWD VPHADDWQ
syn keyword nasmInstructionXOP_FMA4 VPHSUBBW VPHSUBDQ VPHSUBWD VPMACSDD VPMACSDQH
syn keyword nasmInstructionXOP_FMA4 VPMACSDQL VPMACSSDD VPMACSSDQH VPMACSSDQL VPMACSSWD
syn keyword nasmInstructionXOP_FMA4 VPMACSSWW VPMACSWD VPMACSWW VPMADCSSWD VPMADCSWD
syn keyword nasmInstructionXOP_FMA4 VPPERM VPROTB VPROTD VPROTQ VPROTW
syn keyword nasmInstructionXOP_FMA4 VPSHAB VPSHAD VPSHAQ VPSHAW VPSHLB
syn keyword nasmInstructionXOP_FMA4 VPSHLD VPSHLQ VPSHLW
" AVX2
syn keyword nasmInstructionAVX2 VMPSADBW VPABSB VPABSW VPABSD VPACKSSWB
syn keyword nasmInstructionAVX2 VPACKSSDW VPACKUSDW VPACKUSWB VPADDB VPADDW
syn keyword nasmInstructionAVX2 VPADDD VPADDQ VPADDSB VPADDSW VPADDUSB
syn keyword nasmInstructionAVX2 VPADDUSW VPALIGNR VPAND VPANDN VPAVGB
syn keyword nasmInstructionAVX2 VPAVGW VPBLENDVB VPBLENDW VPCMPEQB VPCMPEQW
syn keyword nasmInstructionAVX2 VPCMPEQD VPCMPEQQ VPCMPGTB VPCMPGTW VPCMPGTD
syn keyword nasmInstructionAVX2 VPCMPGTQ VPHADDW VPHADDD VPHADDSW VPHSUBW
syn keyword nasmInstructionAVX2 VPHSUBD VPHSUBSW VPMADDUBSW VPMADDWD VPMAXSB
syn keyword nasmInstructionAVX2 VPMAXSW VPMAXSD VPMAXUB VPMAXUW VPMAXUD
syn keyword nasmInstructionAVX2 VPMINSB VPMINSW VPMINSD VPMINUB VPMINUW
syn keyword nasmInstructionAVX2 VPMINUD VPMOVMSKB VPMOVSXBW VPMOVSXBD VPMOVSXBQ
syn keyword nasmInstructionAVX2 VPMOVSXWD VPMOVSXWQ VPMOVSXDQ VPMOVZXBW VPMOVZXBD
syn keyword nasmInstructionAVX2 VPMOVZXBQ VPMOVZXWD VPMOVZXWQ VPMOVZXDQ VPMULDQ
syn keyword nasmInstructionAVX2 VPMULHRSW VPMULHUW VPMULHW VPMULLW VPMULLD
syn keyword nasmInstructionAVX2 VPMULUDQ VPOR VPSADBW VPSHUFB VPSHUFD
syn keyword nasmInstructionAVX2 VPSHUFHW VPSHUFLW VPSIGNB VPSIGNW VPSIGND
syn keyword nasmInstructionAVX2 VPSLLDQ VPSLLW VPSLLD VPSLLQ VPSRAW
syn keyword nasmInstructionAVX2 VPSRAD VPSRLDQ VPSRLW VPSRLD VPSRLQ
syn keyword nasmInstructionAVX2 VPSUBB VPSUBW VPSUBD VPSUBQ VPSUBSB
syn keyword nasmInstructionAVX2 VPSUBSW VPSUBUSB VPSUBUSW VPUNPCKHBW VPUNPCKHWD
syn keyword nasmInstructionAVX2 VPUNPCKHDQ VPUNPCKHQDQ VPUNPCKLBW VPUNPCKLWD VPUNPCKLDQ
syn keyword nasmInstructionAVX2 VPUNPCKLQDQ VPXOR VMOVNTDQA VBROADCASTSS VBROADCASTSD
syn keyword nasmInstructionAVX2 VBROADCASTI128 VPBLENDD VPBROADCASTB VPBROADCASTW VPBROADCASTD
syn keyword nasmInstructionAVX2 VPBROADCASTQ VPERMD VPERMPD VPERMPS VPERMQ
syn keyword nasmInstructionAVX2 VPERM2I128 VEXTRACTI128 VINSERTI128 VPMASKMOVD VPMASKMOVQ
syn keyword nasmInstructionAVX2 VPMASKMOVD VPMASKMOVQ VPSLLVD VPSLLVQ VPSLLVD
syn keyword nasmInstructionAVX2 VPSLLVQ VPSRAVD VPSRLVD VPSRLVQ VPSRLVD
syn keyword nasmInstructionAVX2 VPSRLVQ VGATHERDPD VGATHERQPD VGATHERDPD VGATHERQPD
syn keyword nasmInstructionAVX2 VGATHERDPS VGATHERQPS VGATHERDPS VGATHERQPS VPGATHERDD
syn keyword nasmInstructionAVX2 VPGATHERQD VPGATHERDD VPGATHERQD VPGATHERDQ VPGATHERQQ
syn keyword nasmInstructionAVX2 VPGATHERDQ VPGATHERQQ
" TRANSACTIONS
syn keyword nasmInstructionTRANSACTIONS XABORT XBEGIN XEND XTEST
" BMI_ABM
syn keyword nasmInstructionBMI_ABM ANDN BEXTR BLCI BLCIC BLSI
syn keyword nasmInstructionBMI_ABM BLSIC BLCFILL BLSFILL BLCMSK BLSMSK
syn keyword nasmInstructionBMI_ABM BLSR BLCS BZHI MULX PDEP
syn keyword nasmInstructionBMI_ABM PEXT RORX SARX SHLX SHRX
syn keyword nasmInstructionBMI_ABM TZCNT TZMSK T1MSKC PREFETCHWT1
" MPE
syn keyword nasmInstructionMPE BNDMK BNDCL BNDCU BNDCN BNDMOV
syn keyword nasmInstructionMPE BNDLDX BNDSTX
" SHA
syn keyword nasmInstructionSHA SHA1MSG1 SHA1MSG2 SHA1NEXTE SHA1RNDS4 SHA256MSG1
syn keyword nasmInstructionSHA SHA256MSG2 SHA256RNDS2 VSHA512MSG1 VSHA512MSG2 VSHA512RNDS2
" SM3
syn keyword nasmInstructionSM3 VSM3MSG1 VSM3MSG2 VSM3RNDS2
" SM4
syn keyword nasmInstructionSM4 VSM4KEY4 VSM4RNDS4
" AVX_NOEXCEPT
syn keyword nasmInstructionAVX_NOEXCEPT VBCSTNEBF16PS VBCSTNESH2PS VCVTNEEBF162PS VCVTNEEPH2PS VCVTNEOBF162PS
syn keyword nasmInstructionAVX_NOEXCEPT VCVTNEOPH2PS VCVTNEPS2BF16
" AVX_VECTOR_NN
syn keyword nasmInstructionAVX_VECTOR_NN VPDPBSSD VPDPBSSDS VPDPBSUD VPDPBSUDS VPDPBUUD
syn keyword nasmInstructionAVX_VECTOR_NN VPDPBUUDS
" AVX_IFMA
syn keyword nasmInstructionAVX_IFMA VPMADD52HUQ VPMADD52LUQ
" AVX512_MASK
syn keyword nasmInstructionAVX512_MASK KADDB KADDD KADDQ KADDW KANDB
syn keyword nasmInstructionAVX512_MASK KANDD KANDNB KANDND KANDNQ KANDNW
syn keyword nasmInstructionAVX512_MASK KANDQ KANDW KMOVB KMOVD KMOVQ
syn keyword nasmInstructionAVX512_MASK KMOVW KNOTB KNOTD KNOTQ KNOTW
syn keyword nasmInstructionAVX512_MASK KORB KORD KORQ KORW KORTESTB
syn keyword nasmInstructionAVX512_MASK KORTESTD KORTESTQ KORTESTW KSHIFTLB KSHIFTLD
syn keyword nasmInstructionAVX512_MASK KSHIFTLQ KSHIFTLW KSHIFTRB KSHIFTRD KSHIFTRQ
syn keyword nasmInstructionAVX512_MASK KSHIFTRW KTESTB KTESTD KTESTQ KTESTW
syn keyword nasmInstructionAVX512_MASK KUNPCKBW KUNPCKDQ KUNPCKWD KXNORB KXNORD
syn keyword nasmInstructionAVX512_MASK KXNORQ KXNORW KXORB KXORD KXORQ
syn keyword nasmInstructionAVX512_MASK KXORW
" AVX512_MASK_REG
syn keyword nasmInstructionAVX512_MASK_REG KADD KAND KANDN KAND KMOV
syn keyword nasmInstructionAVX512_MASK_REG KNOT KOR KORTEST KSHIFTL KSHIFTR
syn keyword nasmInstructionAVX512_MASK_REG KTEST KUNPCK KXNOR KXOR
" AVX512
syn keyword nasmInstructionAVX512 VADDPD VADDPS VADDSD VADDSS VALIGND
syn keyword nasmInstructionAVX512 VALIGNQ VANDNPD VANDNPS VANDPD VANDPS
syn keyword nasmInstructionAVX512 VBLENDMPD VBLENDMPS VBROADCASTF32X2 VBROADCASTF32X4 VBROADCASTF32X8
syn keyword nasmInstructionAVX512 VBROADCASTF64X2 VBROADCASTF64X4 VBROADCASTI32X2 VBROADCASTI32X4 VBROADCASTI32X8
syn keyword nasmInstructionAVX512 VBROADCASTI64X2 VBROADCASTI64X4 VBROADCASTSD VBROADCASTSS VCMPEQPD
syn keyword nasmInstructionAVX512 VCMPEQPS VCMPEQSD VCMPEQSS VCMPEQ_OQPD VCMPEQ_OQPS
syn keyword nasmInstructionAVX512 VCMPEQ_OQSD VCMPEQ_OQSS VCMPLTPD VCMPLTPS VCMPLTSD
syn keyword nasmInstructionAVX512 VCMPLTSS VCMPLT_OSPD VCMPLT_OSPS VCMPLT_OSSD VCMPLT_OSSS
syn keyword nasmInstructionAVX512 VCMPLEPD VCMPLEPS VCMPLESD VCMPLESS VCMPLE_OSPD
syn keyword nasmInstructionAVX512 VCMPLE_OSPS VCMPLE_OSSD VCMPLE_OSSS VCMPUNORDPD VCMPUNORDPS
syn keyword nasmInstructionAVX512 VCMPUNORDSD VCMPUNORDSS VCMPUNORD_QPD VCMPUNORD_QPS VCMPUNORD_QSD
syn keyword nasmInstructionAVX512 VCMPUNORD_QSS VCMPNEQPD VCMPNEQPS VCMPNEQSD VCMPNEQSS
syn keyword nasmInstructionAVX512 VCMPNEQ_UQPD VCMPNEQ_UQPS VCMPNEQ_UQSD VCMPNEQ_UQSS VCMPNLTPD
syn keyword nasmInstructionAVX512 VCMPNLTPS VCMPNLTSD VCMPNLTSS VCMPNLT_USPD VCMPNLT_USPS
syn keyword nasmInstructionAVX512 VCMPNLT_USSD VCMPNLT_USSS VCMPNLEPD VCMPNLEPS VCMPNLESD
syn keyword nasmInstructionAVX512 VCMPNLESS VCMPNLE_USPD VCMPNLE_USPS VCMPNLE_USSD VCMPNLE_USSS
syn keyword nasmInstructionAVX512 VCMPORDPD VCMPORDPS VCMPORDSD VCMPORDSS VCMPORD_QPD
syn keyword nasmInstructionAVX512 VCMPORD_QPS VCMPORD_QSD VCMPORD_QSS VCMPEQ_UQPD VCMPEQ_UQPS
syn keyword nasmInstructionAVX512 VCMPEQ_UQSD VCMPEQ_UQSS VCMPNGEPD VCMPNGEPS VCMPNGESD
syn keyword nasmInstructionAVX512 VCMPNGESS VCMPNGE_USPD VCMPNGE_USPS VCMPNGE_USSD VCMPNGE_USSS
syn keyword nasmInstructionAVX512 VCMPNGTPD VCMPNGTPS VCMPNGTSD VCMPNGTSS VCMPNGT_USPD
syn keyword nasmInstructionAVX512 VCMPNGT_USPS VCMPNGT_USSD VCMPNGT_USSS VCMPFALSEPD VCMPFALSEPS
syn keyword nasmInstructionAVX512 VCMPFALSESD VCMPFALSESS VCMPFALSE_OQPD VCMPFALSE_OQPS VCMPFALSE_OQSD
syn keyword nasmInstructionAVX512 VCMPFALSE_OQSS VCMPNEQ_OQPD VCMPNEQ_OQPS VCMPNEQ_OQSD VCMPNEQ_OQSS
syn keyword nasmInstructionAVX512 VCMPGEPD VCMPGEPS VCMPGESD VCMPGESS VCMPGE_OSPD
syn keyword nasmInstructionAVX512 VCMPGE_OSPS VCMPGE_OSSD VCMPGE_OSSS VCMPGTPD VCMPGTPS
syn keyword nasmInstructionAVX512 VCMPGTSD VCMPGTSS VCMPGT_OSPD VCMPGT_OSPS VCMPGT_OSSD
syn keyword nasmInstructionAVX512 VCMPGT_OSSS VCMPTRUEPD VCMPTRUEPS VCMPTRUESD VCMPTRUESS
syn keyword nasmInstructionAVX512 VCMPTRUE_UQPD VCMPTRUE_UQPS VCMPTRUE_UQSD VCMPTRUE_UQSS VCMPEQ_OSPD
syn keyword nasmInstructionAVX512 VCMPEQ_OSPS VCMPEQ_OSSD VCMPEQ_OSSS VCMPLT_OQPD VCMPLT_OQPS
syn keyword nasmInstructionAVX512 VCMPLT_OQSD VCMPLT_OQSS VCMPLE_OQPD VCMPLE_OQPS VCMPLE_OQSD
syn keyword nasmInstructionAVX512 VCMPLE_OQSS VCMPUNORD_SPD VCMPUNORD_SPS VCMPUNORD_SSD VCMPUNORD_SSS
syn keyword nasmInstructionAVX512 VCMPNEQ_USPD VCMPNEQ_USPS VCMPNEQ_USSD VCMPNEQ_USSS VCMPNLT_UQPD
syn keyword nasmInstructionAVX512 VCMPNLT_UQPS VCMPNLT_UQSD VCMPNLT_UQSS VCMPNLE_UQPD VCMPNLE_UQPS
syn keyword nasmInstructionAVX512 VCMPNLE_UQSD VCMPNLE_UQSS VCMPORD_SPD VCMPORD_SPS VCMPORD_SSD
syn keyword nasmInstructionAVX512 VCMPORD_SSS VCMPEQ_USPD VCMPEQ_USPS VCMPEQ_USSD VCMPEQ_USSS
syn keyword nasmInstructionAVX512 VCMPNGE_UQPD VCMPNGE_UQPS VCMPNGE_UQSD VCMPNGE_UQSS VCMPNGT_UQPD
syn keyword nasmInstructionAVX512 VCMPNGT_UQPS VCMPNGT_UQSD VCMPNGT_UQSS VCMPFALSE_OSPD VCMPFALSE_OSPS
syn keyword nasmInstructionAVX512 VCMPFALSE_OSSD VCMPFALSE_OSSS VCMPNEQ_OSPD VCMPNEQ_OSPS VCMPNEQ_OSSD
syn keyword nasmInstructionAVX512 VCMPNEQ_OSSS VCMPGE_OQPD VCMPGE_OQPS VCMPGE_OQSD VCMPGE_OQSS
syn keyword nasmInstructionAVX512 VCMPGT_OQPD VCMPGT_OQPS VCMPGT_OQSD VCMPGT_OQSS VCMPTRUE_USPD
syn keyword nasmInstructionAVX512 VCMPTRUE_USPS VCMPTRUE_USSD VCMPTRUE_USSS VCMPPD VCMPPS
syn keyword nasmInstructionAVX512 VCMPSD VCMPSS VCOMISD VCOMISS VCOMPRESSPD
syn keyword nasmInstructionAVX512 VCOMPRESSPS VCVTDQ2PD VCVTDQ2PS VCVTPD2DQ VCVTPD2PS
syn keyword nasmInstructionAVX512 VCVTPD2QQ VCVTPD2UDQ VCVTPD2UQQ VCVTPH2PS VCVTPS2DQ
syn keyword nasmInstructionAVX512 VCVTPS2PD VCVTPS2PH VCVTPS2QQ VCVTPS2UDQ VCVTPS2UQQ
syn keyword nasmInstructionAVX512 VCVTQQ2PD VCVTQQ2PS VCVTSD2SI VCVTSD2SS VCVTSD2USI
syn keyword nasmInstructionAVX512 VCVTSI2SD VCVTSI2SS VCVTSS2SD VCVTSS2SI VCVTSS2USI
syn keyword nasmInstructionAVX512 VCVTTPD2DQ VCVTTPD2QQ VCVTTPD2UDQ VCVTTPD2UQQ VCVTTPS2DQ
syn keyword nasmInstructionAVX512 VCVTTPS2QQ VCVTTPS2UDQ VCVTTPS2UQQ VCVTTSD2SI VCVTTSD2USI
syn keyword nasmInstructionAVX512 VCVTTSS2SI VCVTTSS2USI VCVTUDQ2PD VCVTUDQ2PS VCVTUQQ2PD
syn keyword nasmInstructionAVX512 VCVTUQQ2PS VCVTUSI2SD VCVTUSI2SS VDBPSADBW VDIVPD
syn keyword nasmInstructionAVX512 VDIVPS VDIVSD VDIVSS VEXP2PD VEXP2PS
syn keyword nasmInstructionAVX512 VEXPANDPD VEXPANDPS VEXTRACTF32X4 VEXTRACTF32X8 VEXTRACTF64X2
syn keyword nasmInstructionAVX512 VEXTRACTF64X4 VEXTRACTI32X4 VEXTRACTI32X8 VEXTRACTI64X2 VEXTRACTI64X4
syn keyword nasmInstructionAVX512 VEXTRACTPS VFIXUPIMMPD VFIXUPIMMPS VFIXUPIMMSD VFIXUPIMMSS
syn keyword nasmInstructionAVX512 VFMADD132PD VFMADD132PS VFMADD132SD VFMADD132SS VFMADD213PD
syn keyword nasmInstructionAVX512 VFMADD213PS VFMADD213SD VFMADD213SS VFMADD231PD VFMADD231PS
syn keyword nasmInstructionAVX512 VFMADD231SD VFMADD231SS VFMADDSUB132PD VFMADDSUB132PS VFMADDSUB213PD
syn keyword nasmInstructionAVX512 VFMADDSUB213PS VFMADDSUB231PD VFMADDSUB231PS VFMSUB132PD VFMSUB132PS
syn keyword nasmInstructionAVX512 VFMSUB132SD VFMSUB132SS VFMSUB213PD VFMSUB213PS VFMSUB213SD
syn keyword nasmInstructionAVX512 VFMSUB213SS VFMSUB231PD VFMSUB231PS VFMSUB231SD VFMSUB231SS
syn keyword nasmInstructionAVX512 VFMSUBADD132PD VFMSUBADD132PS VFMSUBADD213PD VFMSUBADD213PS VFMSUBADD231PD
syn keyword nasmInstructionAVX512 VFMSUBADD231PS VFNMADD132PD VFNMADD132PS VFNMADD132SD VFNMADD132SS
syn keyword nasmInstructionAVX512 VFNMADD213PD VFNMADD213PS VFNMADD213SD VFNMADD213SS VFNMADD231PD
syn keyword nasmInstructionAVX512 VFNMADD231PS VFNMADD231SD VFNMADD231SS VFNMSUB132PD VFNMSUB132PS
syn keyword nasmInstructionAVX512 VFNMSUB132SD VFNMSUB132SS VFNMSUB213PD VFNMSUB213PS VFNMSUB213SD
syn keyword nasmInstructionAVX512 VFNMSUB213SS VFNMSUB231PD VFNMSUB231PS VFNMSUB231SD VFNMSUB231SS
syn keyword nasmInstructionAVX512 VFPCLASSPD VFPCLASSPS VFPCLASSSD VFPCLASSSS VGATHERDPD
syn keyword nasmInstructionAVX512 VGATHERDPS VGATHERPF0DPD VGATHERPF0DPS VGATHERPF0QPD VGATHERPF0QPS
syn keyword nasmInstructionAVX512 VGATHERPF1DPD VGATHERPF1DPS VGATHERPF1QPD VGATHERPF1QPS VGATHERQPD
syn keyword nasmInstructionAVX512 VGATHERQPS VGETEXPPD VGETEXPPS VGETEXPSD VGETEXPSS
syn keyword nasmInstructionAVX512 VGETMANTPD VGETMANTPS VGETMANTSD VGETMANTSS VINSERTF32X4
syn keyword nasmInstructionAVX512 VINSERTF32X8 VINSERTF64X2 VINSERTF64X4 VINSERTI32X4 VINSERTI32X8
syn keyword nasmInstructionAVX512 VINSERTI64X2 VINSERTI64X4 VINSERTPS VMAXPD VMAXPS
syn keyword nasmInstructionAVX512 VMAXSD VMAXSS VMINPD VMINPS VMINSD
syn keyword nasmInstructionAVX512 VMINSS VMOVAPD VMOVAPS VMOVD VMOVDDUP
syn keyword nasmInstructionAVX512 VMOVDQA32 VMOVDQA64 VMOVDQU16 VMOVDQU32 VMOVDQU64
syn keyword nasmInstructionAVX512 VMOVDQU8 VMOVHLPS VMOVHPD VMOVHPS VMOVLHPS
syn keyword nasmInstructionAVX512 VMOVLPD VMOVLPS VMOVNTDQ VMOVNTDQA VMOVNTPD
syn keyword nasmInstructionAVX512 VMOVNTPS VMOVQ VMOVSD VMOVSHDUP VMOVSLDUP
syn keyword nasmInstructionAVX512 VMOVSS VMOVUPD VMOVUPS VMULPD VMULPS
syn keyword nasmInstructionAVX512 VMULSD VMULSS VORPD VORPS VPABSB
syn keyword nasmInstructionAVX512 VPABSD VPABSQ VPABSW VPACKSSDW VPACKSSWB
syn keyword nasmInstructionAVX512 VPACKUSDW VPACKUSWB VPADDB VPADDD VPADDQ
syn keyword nasmInstructionAVX512 VPADDSB VPADDSW VPADDUSB VPADDUSW VPADDW
syn keyword nasmInstructionAVX512 VPALIGNR VPANDD VPANDND VPANDNQ VPANDQ
syn keyword nasmInstructionAVX512 VPAVGB VPAVGW VPBLENDMB VPBLENDMD VPBLENDMQ
syn keyword nasmInstructionAVX512 VPBLENDMW VPBROADCASTB VPBROADCASTD VPBROADCASTMB2Q VPBROADCASTMW2D
syn keyword nasmInstructionAVX512 VPBROADCASTQ VPBROADCASTW VPCMPEQB VPCMPEQD VPCMPEQQ
syn keyword nasmInstructionAVX512 VPCMPEQW VPCMPGTB VPCMPGTD VPCMPGTQ VPCMPGTW
syn keyword nasmInstructionAVX512 VPCMPEQB VPCMPEQD VPCMPEQQ VPCMPEQUB VPCMPEQUD
syn keyword nasmInstructionAVX512 VPCMPEQUQ VPCMPEQUW VPCMPEQW VPCMPGEB VPCMPGED
syn keyword nasmInstructionAVX512 VPCMPGEQ VPCMPGEUB VPCMPGEUD VPCMPGEUQ VPCMPGEUW
syn keyword nasmInstructionAVX512 VPCMPGEW VPCMPGTB VPCMPGTD VPCMPGTQ VPCMPGTUB
syn keyword nasmInstructionAVX512 VPCMPGTUD VPCMPGTUQ VPCMPGTUW VPCMPGTW VPCMPLEB
syn keyword nasmInstructionAVX512 VPCMPLED VPCMPLEQ VPCMPLEUB VPCMPLEUD VPCMPLEUQ
syn keyword nasmInstructionAVX512 VPCMPLEUW VPCMPLEW VPCMPLTB VPCMPLTD VPCMPLTQ
syn keyword nasmInstructionAVX512 VPCMPLTUB VPCMPLTUD VPCMPLTUQ VPCMPLTUW VPCMPLTW
syn keyword nasmInstructionAVX512 VPCMPNEQB VPCMPNEQD VPCMPNEQQ VPCMPNEQUB VPCMPNEQUD
syn keyword nasmInstructionAVX512 VPCMPNEQUQ VPCMPNEQUW VPCMPNEQW VPCMPNGTB VPCMPNGTD
syn keyword nasmInstructionAVX512 VPCMPNGTQ VPCMPNGTUB VPCMPNGTUD VPCMPNGTUQ VPCMPNGTUW
syn keyword nasmInstructionAVX512 VPCMPNGTW VPCMPNLEB VPCMPNLED VPCMPNLEQ VPCMPNLEUB
syn keyword nasmInstructionAVX512 VPCMPNLEUD VPCMPNLEUQ VPCMPNLEUW VPCMPNLEW VPCMPNLTB
syn keyword nasmInstructionAVX512 VPCMPNLTD VPCMPNLTQ VPCMPNLTUB VPCMPNLTUD VPCMPNLTUQ
syn keyword nasmInstructionAVX512 VPCMPNLTUW VPCMPNLTW VPCMPB VPCMPD VPCMPQ
syn keyword nasmInstructionAVX512 VPCMPUB VPCMPUD VPCMPUQ VPCMPUW VPCMPW
syn keyword nasmInstructionAVX512 VPCOMPRESSD VPCOMPRESSQ VPCONFLICTD VPCONFLICTQ VPERMB
syn keyword nasmInstructionAVX512 VPERMD VPERMI2B VPERMI2D VPERMI2PD VPERMI2PS
syn keyword nasmInstructionAVX512 VPERMI2Q VPERMI2W VPERMILPD VPERMILPS VPERMPD
syn keyword nasmInstructionAVX512 VPERMPS VPERMQ VPERMT2B VPERMT2D VPERMT2PD
syn keyword nasmInstructionAVX512 VPERMT2PS VPERMT2Q VPERMT2W VPERMW VPEXPANDD
syn keyword nasmInstructionAVX512 VPEXPANDQ VPEXTRB VPEXTRD VPEXTRQ VPEXTRW
syn keyword nasmInstructionAVX512 VPGATHERDD VPGATHERDQ VPGATHERQD VPGATHERQQ VPINSRB
syn keyword nasmInstructionAVX512 VPINSRD VPINSRQ VPINSRW VPLZCNTD VPLZCNTQ
syn keyword nasmInstructionAVX512 VPMADD52HUQ VPMADD52LUQ VPMADDUBSW VPMADDWD VPMAXSB
syn keyword nasmInstructionAVX512 VPMAXSD VPMAXSQ VPMAXSW VPMAXUB VPMAXUD
syn keyword nasmInstructionAVX512 VPMAXUQ VPMAXUW VPMINSB VPMINSD VPMINSQ
syn keyword nasmInstructionAVX512 VPMINSW VPMINUB VPMINUD VPMINUQ VPMINUW
syn keyword nasmInstructionAVX512 VPMOVB2M VPMOVD2M VPMOVDB VPMOVDW VPMOVM2B
syn keyword nasmInstructionAVX512 VPMOVM2D VPMOVM2Q VPMOVM2W VPMOVQ2M VPMOVQB
syn keyword nasmInstructionAVX512 VPMOVQD VPMOVQW VPMOVSDB VPMOVSDW VPMOVSQB
syn keyword nasmInstructionAVX512 VPMOVSQD VPMOVSQW VPMOVSWB VPMOVSXBD VPMOVSXBQ
syn keyword nasmInstructionAVX512 VPMOVSXBW VPMOVSXDQ VPMOVSXWD VPMOVSXWQ VPMOVUSDB
syn keyword nasmInstructionAVX512 VPMOVUSDW VPMOVUSQB VPMOVUSQD VPMOVUSQW VPMOVUSWB
syn keyword nasmInstructionAVX512 VPMOVW2M VPMOVWB VPMOVZXBD VPMOVZXBQ VPMOVZXBW
syn keyword nasmInstructionAVX512 VPMOVZXDQ VPMOVZXWD VPMOVZXWQ VPMULDQ VPMULHRSW
syn keyword nasmInstructionAVX512 VPMULHUW VPMULHW VPMULLD VPMULLQ VPMULLW
syn keyword nasmInstructionAVX512 VPMULTISHIFTQB VPMULUDQ VPORD VPORQ VPROLD
syn keyword nasmInstructionAVX512 VPROLQ VPROLVD VPROLVQ VPRORD VPRORQ
syn keyword nasmInstructionAVX512 VPRORVD VPRORVQ VPSADBW VPSCATTERDD VPSCATTERDQ
syn keyword nasmInstructionAVX512 VPSCATTERQD VPSCATTERQQ VPSHUFB VPSHUFD VPSHUFHW
syn keyword nasmInstructionAVX512 VPSHUFLW VPSLLD VPSLLDQ VPSLLQ VPSLLVD
syn keyword nasmInstructionAVX512 VPSLLVQ VPSLLVW VPSLLW VPSRAD VPSRAQ
syn keyword nasmInstructionAVX512 VPSRAVD VPSRAVQ VPSRAVW VPSRAW VPSRLD
syn keyword nasmInstructionAVX512 VPSRLDQ VPSRLQ VPSRLVD VPSRLVQ VPSRLVW
syn keyword nasmInstructionAVX512 VPSRLW VPSUBB VPSUBD VPSUBQ VPSUBSB
syn keyword nasmInstructionAVX512 VPSUBSW VPSUBUSB VPSUBUSW VPSUBW VPTERNLOGD
syn keyword nasmInstructionAVX512 VPTERNLOGQ VPTESTMB VPTESTMD VPTESTMQ VPTESTMW
syn keyword nasmInstructionAVX512 VPTESTNMB VPTESTNMD VPTESTNMQ VPTESTNMW VPUNPCKHBW
syn keyword nasmInstructionAVX512 VPUNPCKHDQ VPUNPCKHQDQ VPUNPCKHWD VPUNPCKLBW VPUNPCKLDQ
syn keyword nasmInstructionAVX512 VPUNPCKLQDQ VPUNPCKLWD VPXORD VPXORQ VRANGEPD
syn keyword nasmInstructionAVX512 VRANGEPS VRANGESD VRANGESS VRCP14PD VRCP14PS
syn keyword nasmInstructionAVX512 VRCP14SD VRCP14SS VRCP28PD VRCP28PS VRCP28SD
syn keyword nasmInstructionAVX512 VRCP28SS VREDUCEPD VREDUCEPS VREDUCESD VREDUCESS
syn keyword nasmInstructionAVX512 VRNDSCALEPD VRNDSCALEPS VRNDSCALESD VRNDSCALESS VRSQRT14PD
syn keyword nasmInstructionAVX512 VRSQRT14PS VRSQRT14SD VRSQRT14SS VRSQRT28PD VRSQRT28PS
syn keyword nasmInstructionAVX512 VRSQRT28SD VRSQRT28SS VSCALEFPD VSCALEFPS VSCALEFSD
syn keyword nasmInstructionAVX512 VSCALEFSS VSCATTERDPD VSCATTERDPS VSCATTERPF0DPD VSCATTERPF0DPS
syn keyword nasmInstructionAVX512 VSCATTERPF0QPD VSCATTERPF0QPS VSCATTERPF1DPD VSCATTERPF1DPS VSCATTERPF1QPD
syn keyword nasmInstructionAVX512 VSCATTERPF1QPS VSCATTERQPD VSCATTERQPS VSHUFF32X4 VSHUFF64X2
syn keyword nasmInstructionAVX512 VSHUFI32X4 VSHUFI64X2 VSHUFPD VSHUFPS VSQRTPD
syn keyword nasmInstructionAVX512 VSQRTPS VSQRTSD VSQRTSS VSUBPD VSUBPS
syn keyword nasmInstructionAVX512 VSUBSD VSUBSS VUCOMISD VUCOMISS VUNPCKHPD
syn keyword nasmInstructionAVX512 VUNPCKHPS VUNPCKLPD VUNPCKLPS VXORPD VXORPS
" PROTECTION
syn keyword nasmInstructionPROTECTION RDPKRU WRPKRU
" RDPID
syn keyword nasmInstructionRDPID RDPID 
" NMEM
syn keyword nasmInstructionNMEM CLFLUSHOPT CLWB PCOMMIT
syn keyword nasmInstructionNMEM CLZERO
" INTEL_EXTENSIONS
syn keyword nasmInstructionINTEL_EXTENSIONS CLDEMOTE MOVDIRI MOVDIR64B PCONFIG TPAUSE
syn keyword nasmInstructionINTEL_EXTENSIONS UMONITOR UMWAIT WBNOINVD
" GALOISFIELD
syn keyword nasmInstructionGALOISFIELD GF2P8AFFINEINVQB VGF2P8AFFINEINVQB GF2P8AFFINEQB VGF2P8AFFINEQB GF2P8MULB
syn keyword nasmInstructionGALOISFIELD VGF2P8MULB
" AVX512_BMI
syn keyword nasmInstructionAVX512_BMI VPCOMPRESSB VPCOMPRESSW VPEXPANDB VPEXPANDW VPSHLDW
syn keyword nasmInstructionAVX512_BMI VPSHLDD VPSHLDQ VPSHLDVW VPSHLDVD VPSHLDVQ
syn keyword nasmInstructionAVX512_BMI VPSHRDW VPSHRDD VPSHRDQ VPSHRDVW VPSHRDVD
syn keyword nasmInstructionAVX512_BMI VPSHRDVQ
" AVX512_VNNI
syn keyword nasmInstructionAVX512_VNNI VPDPBUSD VPDPBUSDS VPDPWSSD VPDPWSSDS
" AVX512_BITALG
syn keyword nasmInstructionAVX512_BITALG VPOPCNTB VPOPCNTW VPOPCNTD VPOPCNTQ VPSHUFBITQMB
" AVX512_FMA
syn keyword nasmInstructionAVX512_FMA V4FMADDPS V4FNMADDPS V4FMADDSS V4FNMADDSS
" AVX512_DP
syn keyword nasmInstructionAVX512_DP V4DPWSSDS V4DPWSSD
" SGX
syn keyword nasmInstructionSGX ENCLS ENCLU ENCLV
" CET
syn keyword nasmInstructionCET CLRSSBSY ENDBR32 ENDBR64 INCSSPD INCSSPQ
syn keyword nasmInstructionCET RDSSPD RDSSPQ RSTORSSP SAVEPREVSSP SETSSBSY
syn keyword nasmInstructionCET WRUSSD WRUSSQ WRSSD WRSSQ
" INTEL_EXTENSION
syn keyword nasmInstructionINTEL_EXTENSION ENQCMD ENQCMDS PCONFIG SERIALIZE WBNOINVD
syn keyword nasmInstructionINTEL_EXTENSION XRESLDTRK XSUSLDTRK
" AVX512_BF16
syn keyword nasmInstructionAVX512_BF16 VCVTNE2PS2BF16 VCVTNEPS2BF16 VDPBF16PS
" AVX512_MASK_INTERSECT
syn keyword nasmInstructionAVX512_MASK_INTERSECT VP2INTERSECTD 
" AMX
syn keyword nasmInstructionAMX LDTILECFG STTILECFG TDPBF16PS TDPBSSD TDPBSUD
syn keyword nasmInstructionAMX TDPBUSD TDPBUUD TILELOADD TILELOADDT1 TILERELEASE
syn keyword nasmInstructionAMX TILESTORED TILEZERO
" AVX512_FP16
syn keyword nasmInstructionAVX512_FP16 VADDPH VADDSH VCMPPH VCMPSH VCOMISH
syn keyword nasmInstructionAVX512_FP16 VCVTDQ2PH VCVTPD2PH VCVTPH2DQ VCVTPH2PD VCVTPH2PS
syn keyword nasmInstructionAVX512_FP16 VCVTPH2PSX VCVTPH2QQ VCVTPH2UDQ VCVTPH2UQQ VCVTPH2UW
syn keyword nasmInstructionAVX512_FP16 VCVTPH2W VCVTPS2PH VCVTQQ2PH VCVTSD2SH VCVTSH2SD
syn keyword nasmInstructionAVX512_FP16 VCVTSH2SI VCVTSH2SS VCVTSH2USI VCVTSI2SH VCVTSS2SH
syn keyword nasmInstructionAVX512_FP16 VCVTTPH2DQ VCVTTPH2QQ VCVTTPH2UDQ VCVTTPH2UQQ VCVTTPH2UW
syn keyword nasmInstructionAVX512_FP16 VCVTTPH2W VCVTTSH2SI VCVTTSH2USI VCVTUDQ2PH VCVTUQQ2PH
syn keyword nasmInstructionAVX512_FP16 VCVTUSI2SH VCVTUSI2SS VCVTUW2PH VCVTW2PH VDIVPH
syn keyword nasmInstructionAVX512_FP16 VDIVSH VFCMADDCPH VFMADDCPH VFCMADDCSH VFMADDCSH
syn keyword nasmInstructionAVX512_FP16 VFCMULCPCH VFMULCPCH VFCMULCSH VFMULCSH VFMADDSUB132PH
syn keyword nasmInstructionAVX512_FP16 VFMADDSUB213PH VFMADDSUB231PH VFMSUBADD132PH VFMSUBADD213PH VFMSUBADD231PH
syn keyword nasmInstructionAVX512_FP16 VPMADD132PH VPMADD213PH VPMADD231PH VFMADD132PH VFMADD213PH
syn keyword nasmInstructionAVX512_FP16 VFMADD231PH VPMADD132SH VPMADD213SH VPMADD231SH VPNMADD132SH
syn keyword nasmInstructionAVX512_FP16 VPNMADD213SH VPNMADD231SH VPMSUB132PH VPMSUB213PH VPMSUB231PH
syn keyword nasmInstructionAVX512_FP16 VFMSUB132PH VFMSUB213PH VFMSUB231PH VPMSUB132SH VPMSUB213SH
syn keyword nasmInstructionAVX512_FP16 VPMSUB231SH VPNMSUB132SH VPNMSUB213SH VPNMSUB231SH VFPCLASSPH
syn keyword nasmInstructionAVX512_FP16 VFPCLASSSH VGETEXPPH VGETEXPSH VGETMANTPH VGETMANTSH
syn keyword nasmInstructionAVX512_FP16 VGETMAXPH VGETMAXSH VGETMINPH VGETMINSH VMOVSH
syn keyword nasmInstructionAVX512_FP16 VMOVW VMULPH VMULSH VRCPPH VRCPSH
syn keyword nasmInstructionAVX512_FP16 VREDUCEPH VREDUCESH VENDSCALEPH VENDSCALESH VRSQRTPH
syn keyword nasmInstructionAVX512_FP16 VRSQRTSH VSCALEFPH VSCALEFSH VSQRTPH VSQRTSH
syn keyword nasmInstructionAVX512_FP16 VSUBPH VSUBSH VUCOMISH
" RAO-INT
syn keyword nasmInstructionRAO_INT AADD AAND AXOR
" USERINT
syn keyword nasmInstructionUSERINT CLUI SENDUIPI STUI TESTUI UIRET
" CMPCCXADD
syn keyword nasmInstructionCMPCCXADD CMPOXADD CMPNOXADD CMPBXADD CMPNBXADD CMPZXADD
syn keyword nasmInstructionCMPCCXADD CMPNZXADD CMPBEXADD CMPNBEXADD CMPSXADD CMPNSXADD
syn keyword nasmInstructionCMPCCXADD CMPPXADD CMPNPXADD CMPLXADD CMPNLXADD CMPLEXADD
syn keyword nasmInstructionCMPCCXADD CMPNLEXADD
" FRET
syn keyword nasmInstructionFRET ERETS ERETU LKGS
" WRMSRNS_MSRLIST
syn keyword nasmInstructionWRMSRNS_MSRLIST WRMSRNS RDMSRLIST WRMSRLIST
" HRESET
syn keyword nasmInstructionHRESET HRESET 
" PTWRITE
syn keyword nasmInstructionPTWRITE PTWRITE 
" HINTNOP
syn keyword nasmInstructionHINTNOP HINT_NOP0 HINT_NOP1 HINT_NOP2 HINT_NOP3 HINT_NOP4
syn keyword nasmInstructionHINTNOP HINT_NOP5 HINT_NOP6 HINT_NOP7 HINT_NOP8 HINT_NOP9
syn keyword nasmInstructionHINTNOP HINT_NOP10 HINT_NOP11 HINT_NOP12 HINT_NOP13 HINT_NOP14
syn keyword nasmInstructionHINTNOP HINT_NOP15 HINT_NOP16 HINT_NOP17 HINT_NOP18 HINT_NOP19
syn keyword nasmInstructionHINTNOP HINT_NOP20 HINT_NOP21 HINT_NOP22 HINT_NOP23 HINT_NOP24
syn keyword nasmInstructionHINTNOP HINT_NOP25 HINT_NOP26 HINT_NOP27 HINT_NOP28 HINT_NOP29
syn keyword nasmInstructionHINTNOP HINT_NOP30 HINT_NOP31 HINT_NOP32 HINT_NOP33 HINT_NOP34
syn keyword nasmInstructionHINTNOP HINT_NOP35 HINT_NOP36 HINT_NOP37 HINT_NOP38 HINT_NOP39
syn keyword nasmInstructionHINTNOP HINT_NOP40 HINT_NOP41 HINT_NOP42 HINT_NOP43 HINT_NOP44
syn keyword nasmInstructionHINTNOP HINT_NOP45 HINT_NOP46 HINT_NOP47 HINT_NOP48 HINT_NOP49
syn keyword nasmInstructionHINTNOP HINT_NOP50 HINT_NOP51 HINT_NOP52 HINT_NOP53 HINT_NOP54
syn keyword nasmInstructionHINTNOP HINT_NOP55 HINT_NOP56 HINT_NOP57 HINT_NOP58 HINT_NOP59
syn keyword nasmInstructionHINTNOP HINT_NOP60 HINT_NOP61 HINT_NOP62 HINT_NOP63
"  Cyrix instructions (requires Cyrix processor)
syn keyword nasmCrxInstruction	PADDSIW PAVEB PDISTIB PMAGW PMULHRWC PMULHRIW
syn keyword nasmCrxInstruction	PMVGEZB PMVLZB PMVNZB PMVZB PSUBSIW
syn keyword nasmCrxInstruction	RDSHR RSDC RSLDT SMINT SMINTOLD SVDC SVLDT SVTS
syn keyword nasmCrxInstruction	WRSHR BB0_RESET BB1_RESET
syn keyword nasmCrxInstruction	CPU_WRITE CPU_READ DMINT RDM PMACHRIW

" Debugging Instructions: (privileged)
syn keyword nasmDbgInstruction	INT1 INT3 RDMSR RDTSC RDPMC WRMSR INT01 INT03


" Synchronize Syntax:
syn sync clear
syn sync minlines=50		"for multiple region nesting
syn sync match  nasmSync	grouphere nasmMacroDef "^\s*%i\=macro\>"me=s-1
syn sync match	nasmSync	grouphere NONE	       "^\s*%endmacro\>"


" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" Sub Links:
hi def link nasmInMacDirective	nasmDirective
hi def link nasmInMacLabel		nasmLocalLabel
hi def link nasmInMacLblWarn	nasmLabelWarn
hi def link nasmInMacMacro		nasmMacro
hi def link nasmInMacParam		nasmMacro
hi def link nasmInMacParamNum	nasmDecNumber
hi def link nasmInMacPreCondit	nasmPreCondit
hi def link nasmInMacPreProc	nasmPreProc
hi def link nasmInPreCondit	nasmPreCondit
hi def link nasmInStructure	nasmStructure
hi def link nasmStructureLabel	nasmStructure

" Comment Group:
hi def link nasmComment		Comment
hi def link nasmSpecialComment	SpecialComment
hi def link nasmInCommentTodo	Todo

" Constant Group:
hi def link nasmString		String
hi def link nasmCString	String
hi def link nasmStringError	Error
hi def link nasmCStringEscape	SpecialChar
hi def link nasmCStringFormat	SpecialChar
hi def link nasmBinNumber		Number
hi def link nasmOctNumber		Number
hi def link nasmDecNumber		Number
hi def link nasmHexNumber		Number
hi def link nasmBinFloat		Float
hi def link nasmOctFloat		Float
hi def link nasmDecFloat		Float
hi def link nasmHexFloat		Float
hi def link nasmSpecFloat		Float
hi def link nasmBcdConst		Float
hi def link nasmNumberError	Error

" Identifier Group:
hi def link nasmLabel		Identifier
hi def link nasmLocalLabel		Identifier
hi def link nasmSpecialLabel	Special
hi def link nasmLabelError		Error
hi def link nasmLabelWarn		Todo

" PreProc Group:
hi def link nasmPreProc		PreProc
hi def link nasmDefine		Define
hi def link nasmInclude		Include
hi def link nasmMacro		Macro
hi def link nasmPreCondit		PreCondit
hi def link nasmPreProcError	Error
hi def link nasmPreProcWarn	Todo

" Type Group:
hi def link nasmType		Type
hi def link nasmStorage		StorageClass
hi def link nasmStructure		Structure
hi def link nasmTypeError		Error

" Directive Group:
hi def link nasmConstant		Constant
hi def link nasmInstrModifier	Operator
hi def link nasmRepeat		Repeat
hi def link nasmDirective		Keyword
hi def link nasmStdDirective	Operator
hi def link nasmFmtDirective	Keyword

" Register Group:
hi def link nasmRegisterError	Error
hi def link nasmCtrlRegister	Special
hi def link nasmDebugRegister	Debug
hi def link nasmTestRegister	Special
hi def link nasmRegisterError	Error
hi def link nasmMemRefError	Error

" Instruction Group:
hi def link nasmInstructnError	Error
hi def link nasmCrxInstruction	Special
hi def link nasmDbgInstruction	Debug
hi def link nasmInstructionStandard Statement
hi def link nasmInstructionSIMD Statement
hi def link nasmInstructionSSE Statement
hi def link nasmInstructionXSAVE Statement
hi def link nasmInstructionMEM Statement
hi def link nasmInstructionMMX Statement
hi def link nasmInstruction3DNOW Statement
hi def link nasmInstructionSSE2 Statement
hi def link nasmInstructionWMMX Statement
hi def link nasmInstructionWSSD Statement
hi def link nasmInstructionPRESSCOT Statement
hi def link nasmInstructionVMXSVM Statement
hi def link nasmInstructionPTVMX Statement
hi def link nasmInstructionSEVSNPAMD Statement
hi def link nasmInstructionTEJAS Statement
hi def link nasmInstructionAMD_SSE4A Statement
hi def link nasmInstructionBARCELONA Statement
hi def link nasmInstructionPENRY Statement
hi def link nasmInstructionNEHALEM Statement
hi def link nasmInstructionSMX Statement
hi def link nasmInstructionGEODE_3DNOW Statement
hi def link nasmInstructionINTEL_NEW Statement
hi def link nasmInstructionAES Statement
hi def link nasmInstructionAVX_AES Statement
hi def link nasmInstructionINTEL_PUB Statement
hi def link nasmInstructionAVX Statement
hi def link nasmInstructionINTEL_CMUL Statement
hi def link nasmInstructionINTEL_AVX_CMUL Statement
hi def link nasmInstructionINTEL_FMA Statement
hi def link nasmInstructionINTEL_POST32 Statement
hi def link nasmInstructionSUPERVISOR Statement
hi def link nasmInstructionVIA_SECURITY Statement
hi def link nasmInstructionAMD_PROFILING Statement
hi def link nasmInstructionXOP_FMA4 Statement
hi def link nasmInstructionAVX2 Statement
hi def link nasmInstructionTRANSACTIONS Statement
hi def link nasmInstructionBMI_ABM Statement
hi def link nasmInstructionMPE Statement
hi def link nasmInstructionSHA Statement
hi def link nasmInstructionSM3 Statement
hi def link nasmInstructionSM4 Statement
hi def link nasmInstructionAVX_NOEXCEPT Statement
hi def link nasmInstructionAVX_VECTOR_NN Statement
hi def link nasmInstructionAVX_IFMA Statement
hi def link nasmInstructionAVX512_MASK Statement
hi def link nasmInstructionAVX512_MASK_REG Statement
hi def link nasmInstructionAVX512 Statement
hi def link nasmInstructionPROTECTION Statement
hi def link nasmInstructionRDPID Statement
hi def link nasmInstructionNMEM Statement
hi def link nasmInstructionINTEL_EXTENSIONS Statement
hi def link nasmInstructionGALOISFIELD Statement
hi def link nasmInstructionAVX512_BMI Statement
hi def link nasmInstructionAVX512_VNNI Statement
hi def link nasmInstructionAVX512_BITALG Statement
hi def link nasmInstructionAVX512_FMA Statement
hi def link nasmInstructionAVX512_DP Statement
hi def link nasmInstructionSGX Statement
hi def link nasmInstructionCET Statement
hi def link nasmInstructionINTEL_EXTENSION Statement
hi def link nasmInstructionAVX512_BF16 Statement
hi def link nasmInstructionAVX512_MASK_INTERSECT Statement
hi def link nasmInstructionAMX Statement
hi def link nasmInstructionAVX512_FP16 Statement
hi def link nasmInstructionRAO_INT Statement
hi def link nasmInstructionUSERINT Statement
hi def link nasmInstructionCMPCCXADD Statement
hi def link nasmInstructionFRET Statement
hi def link nasmInstructionWRMSRNS_MSRLIST Statement
hi def link nasmInstructionHRESET Statement
hi def link nasmInstructionHINTNOP Statement
hi def link nasmInstructionPTWRITE Statement

let b:current_syntax = "nasm"

" vim:ts=8 sw=4
