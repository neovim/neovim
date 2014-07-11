" Vim syntax file for the D programming language (version 1.076 and 2.063).
"
" Language:     D
" Maintainer:   Jesse Phillips <Jesse.K.Phillips+D@gmail.com>
" Last Change:  2013 October 5
" Version:      0.26
"
" Contributors:
"   - Jason Mills: original Maintainer
"   - Kirk McDonald
"   - Tim Keating
"   - Frank Benoit
"   - Shougo Matsushita
"   - Ellery Newcomer
"   - Steven N. Oliver
"   - Sohgo Takeuchi
"   - Robert Clipsham
"
" Please submit bugs/comments/suggestions to the github repo: 
" https://github.com/JesseKPhillips/d.vim
"
" Options:
"   d_comment_strings - Set to highlight strings and numbers in comments.
"
"   d_hl_operator_overload - Set to highlight D's specially named functions
"   that when overloaded implement unary and binary operators (e.g. opCmp).
"
"   d_hl_object_types - Set to highlight some common types from object.di.

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Support cpoptions
let s:cpo_save = &cpo
set cpo&vim

" Set the current syntax to be known as d
let b:current_syntax = "d"

" Keyword definitions
"
syn keyword dExternal              contained import module
syn keyword dAssert                assert
syn keyword dConditional           if else switch
syn keyword dBranch                goto break continue
syn keyword dRepeat                while for do foreach foreach_reverse
syn keyword dBoolean               true false
syn keyword dConstant              null
syn keyword dConstant              __FILE__ __LINE__ __EOF__ __VERSION__
syn keyword dConstant              __DATE__ __TIME__ __TIMESTAMP__ __VENDOR__
syn keyword dConstant              __MODULE__ __FUNCTION__ __PRETTY_FUNCTION__
syn keyword dTypedef               alias typedef
syn keyword dStructure             template interface class struct union
syn keyword dEnum                  enum
syn keyword dOperator              new delete typeof typeid cast align is
syn keyword dOperator              this super
if exists("d_hl_operator_overload")
  syn keyword dOpOverload          opNeg opCom opPostInc opPostDec opCast opAdd
  syn keyword dOpOverload          opSub opSub_r opMul opDiv opDiv_r opMod 
  syn keyword dOpOverload          opMod_r opAnd opOr opXor opShl opShl_r opShr
  syn keyword dOpOverload          opShr_r opUShr opUShr_r opCat
  syn keyword dOpOverload          opCat_r opEquals opCmp
  syn keyword dOpOverload          opAssign opAddAssign opSubAssign opMulAssign
  syn keyword dOpOverload          opDivAssign opModAssign opAndAssign 
  syn keyword dOpOverload          opOrAssign opXorAssign opShlAssign 
  syn keyword dOpOverload          opShrAssign opUShrAssign opCatAssign
  syn keyword dOpOverload          opIndex opIndexAssign opIndexOpAssign
  syn keyword dOpOverload          opCall opSlice opSliceAssign opSliceOpAssign 
  syn keyword dOpOverload          opPos opAdd_r opMul_r opAnd_r opOr_r opXor_r
  syn keyword dOpOverload          opIn opIn_r opPow opDispatch opStar opDot 
  syn keyword dOpOverload          opApply opApplyReverse opDollar
  syn keyword dOpOverload          opUnary opIndexUnary opSliceUnary
  syn keyword dOpOverload          opBinary opBinaryRight
endif

syn keyword dType                  byte ubyte short ushort int uint long ulong cent ucent
syn keyword dType                  void bool Object
syn keyword dType                  float double real
syn keyword dType                  ushort int uint long ulong float
syn keyword dType                  char wchar dchar string wstring dstring
syn keyword dType                  ireal ifloat idouble creal cfloat cdouble
syn keyword dType                  size_t ptrdiff_t sizediff_t equals_t hash_t
if exists("d_hl_object_types")
  syn keyword dType                Object Throwable AssociativeArray Error Exception
  syn keyword dType                Interface OffsetTypeInfo TypeInfo TypeInfo_Typedef
  syn keyword dType                TypeInfo_Enum TypeInfo_Pointer TypeInfo_Array
  syn keyword dType                TypeInfo_StaticArray TypeInfo_AssociativeArray
  syn keyword dType                TypeInfo_Function TypeInfo_Delegate TypeInfo_Class
  syn keyword dType                ClassInfo TypeInfo_Interface TypeInfo_Struct
  syn keyword dType                TypeInfo_Tuple TypeInfo_Const TypeInfo_Invariant
  syn keyword dType                TypeInfo_Shared TypeInfo_Inout MemberInfo
  syn keyword dType                MemberInfo_field MemberInfo_function ModuleInfo
endif
syn keyword dDebug                 deprecated unittest invariant
syn keyword dExceptions            throw try catch finally
syn keyword dScopeDecl             public protected private export package 
syn keyword dStatement             debug return with
syn keyword dStatement             function delegate __ctfe mixin macro __simd
syn keyword dStatement             in out body
syn keyword dStorageClass          contained in out scope
syn keyword dStorageClass          inout ref lazy pure nothrow
syn keyword dStorageClass          auto static override final abstract volatile
syn keyword dStorageClass          __gshared __vector
syn keyword dStorageClass          synchronized shared immutable const lazy
syn keyword dIdentifier            _arguments _argptr __vptr __monitor
syn keyword dIdentifier             _ctor _dtor __argTypes __overloadset
syn keyword dScopeIdentifier       contained exit success failure
syn keyword dTraitsIdentifier      contained isAbstractClass isArithmetic
syn keyword dTraitsIdentifier      contained isAssociativeArray isFinalClass
syn keyword dTraitsIdentifier      contained isPOD isNested isFloating
syn keyword dTraitsIdentifier      contained isIntegral isScalar isStaticArray
syn keyword dTraitsIdentifier      contained isUnsigned isVirtualFunction
syn keyword dTraitsIdentifier      contained isVirtualMethod isAbstractFunction
syn keyword dTraitsIdentifier      contained isFinalFunction isStaticFunction
syn keyword dTraitsIdentifier      contained isRef isOut isLazy hasMember
syn keyword dTraitsIdentifier      contained identifier getAttributes getMember
syn keyword dTraitsIdentifier      contained getOverloads getProtection
syn keyword dTraitsIdentifier      contained getVirtualFunctions
syn keyword dTraitsIdentifier      contained getVirtualMethods parent
syn keyword dTraitsIdentifier      contained classInstanceSize allMembers
syn keyword dTraitsIdentifier      contained derivedMembers isSame compiles
syn keyword dPragmaIdentifier      contained lib msg startaddress GNU_asm
syn keyword dExternIdentifier      contained Windows Pascal Java System D
syn keyword dAttribute             contained safe trusted system
syn keyword dAttribute             contained property disable
syn keyword dVersionIdentifier     contained DigitalMars GNU LDC SDC D_NET
syn keyword dVersionIdentifier     contained X86 X86_64 ARM PPC PPC64 IA64 MIPS MIPS64 Alpha
syn keyword dVersionIdentifier     contained SPARC SPARC64 S390 S390X HPPA HPPA64 SH SH64
syn keyword dVersionIdentifier     contained linux Posix OSX FreeBSD Windows Win32 Win64
syn keyword dVersionIdentifier     contained OpenBSD BSD Solaris AIX SkyOS SysV3 SysV4 Hurd
syn keyword dVersionIdentifier     contained Cygwin MinGW
syn keyword dVersionIdentifier     contained LittleEndian BigEndian
syn keyword dVersionIdentifier     contained D_InlineAsm_X86 D_InlineAsm_X86_64
syn keyword dVersionIdentifier     contained D_Version2 D_Coverage D_Ddoc D_LP64 D_PIC
syn keyword dVersionIdentifier     contained unittest none all

syn cluster dComment contains=dNestedComment,dBlockComment,dLineComment

" Highlight the sharpbang
syn match dSharpBang "\%^#!.*"     display

" Attributes/annotations
syn match dAnnotation	"@[_$a-zA-Z][_$a-zA-Z0-9_]*\>" contains=dAttribute

" Version Identifiers
syn match dVersion      "\<version\>"
syn match dVersion      "\<version\s*([_a-zA-Z][_a-zA-Z0-9]*\>"he=s+7 contains=dVersionIdentifier

" Scope Identifiers
syn match dStatement    "\<scope\>"
syn match dStatement    "\<scope\s*([_a-zA-Z][_a-zA-Z0-9]*\>"he=s+5 contains=dScopeIdentifier

" Traits Statement
syn match dStatement    "\<__traits\>"
syn match dStatement    "\<__traits\s*([_a-zA-Z][_a-zA-Z0-9]*\>"he=s+8 contains=dTraitsIdentifier

" Pragma Statement
syn match dPragma       "\<pragma\>"
syn match dPragma       "\<pragma\s*([_a-zA-Z][_a-zA-Z0-9]*\>"he=s+6 contains=dPragmaIdentifier

" Necessary to highlight C++ in extern modifiers.
syn match dExternIdentifier "C\(++\)\?" contained

" Extern Identifiers
syn match dExternal     "\<extern\>"
syn match dExtern       "\<extern\s*([_a-zA-Z][_a-zA-Z0-9\+]*\>"he=s+6 contains=dExternIdentifier

" Make import a region to prevent highlighting keywords
syn region dImport start="import\_s" end=";" contains=dExternal,@dComment

" Make module a region to prevent highlighting keywords
syn region dImport start="module\_s" end=";" contains=dExternal,@dComment

" dTokens is used by the token string highlighting
syn cluster dTokens contains=dExternal,dConditional,dBranch,dRepeat,dBoolean
syn cluster dTokens add=dConstant,dTypedef,dStructure,dOperator,dOpOverload
syn cluster dTokens add=dType,dDebug,dExceptions,dScopeDecl,dStatement
syn cluster dTokens add=dStorageClass,dPragma,dAssert,dAnnotation,dEnum
syn cluster dTokens add=dParenString,dBrackString,dAngleString,dCurlyString
syn cluster dTokens add=dTokenString,dDelimString,dHereString

" Create a match for parameter lists to identify storage class
syn region paramlist start="(" end=")" contains=@dTokens

" Labels
"
" We contain dScopeDecl so public: private: etc. are not highlighted like labels
syn match dUserLabel    "^\s*[_$a-zA-Z][_$a-zA-Z0-9_]*\s*:"he=e-1 contains=dLabel,dScopeDecl,dEnum
syn keyword dLabel      case default

syn cluster dTokens add=dUserLabel,dLabel

" Comments
"
syn match	dCommentError	display "\*/"
syn match	dNestedCommentError	display "+/"

syn keyword dTodo                                                                contained TODO FIXME TEMP REFACTOR REVIEW HACK BUG XXX
syn match dCommentStar	contained "^\s*\*[^/]"me=e-1
syn match dCommentStar	contained "^\s*\*$"
syn match dCommentPlus	contained "^\s*+[^/]"me=e-1
syn match dCommentPlus	contained "^\s*+$"
if exists("d_comment_strings")
  syn region dBlockCommentString	contained start=+"+ end=+"+ end=+\*/+me=s-1,he=s-1 contains=dCommentStar,dUnicode,dEscSequence,@Spell
  syn region dNestedCommentString	contained start=+"+ end=+"+ end="+"me=s-1,he=s-1 contains=dCommentPlus,dUnicode,dEscSequence,@Spell
  syn region dLineCommentString		contained start=+"+ end=+$\|"+ contains=dUnicode,dEscSequence,@Spell
endif

syn region dBlockComment	start="/\*"  end="\*/" contains=dBlockCommentString,dTodo,dCommentStartError,@Spell fold
syn region dNestedComment	start="/+"  end="+/" contains=dNestedComment,dNestedCommentString,dTodo,@Spell fold
syn match  dLineComment	"//.*" contains=dLineCommentString,dTodo,@Spell

hi link dLineCommentString	dBlockCommentString
hi link dBlockCommentString	dString
hi link dNestedCommentString	dString
hi link dCommentStar		dBlockComment
hi link dCommentPlus		dNestedComment

syn cluster dTokens add=dBlockComment,dNestedComment,dLineComment

" /+ +/ style comments and strings that span multiple lines can cause
" problems. To play it safe, set minlines to a large number.
syn sync minlines=200
" Use ccomment for /* */ style comments
syn sync ccomment dBlockComment

" Characters
"
syn match dSpecialCharError contained "[^']"

" Escape sequences (oct,specal char,hex,wchar, character entities \&xxx;)
" These are not contained because they are considered string literals.
syn match dEscSequence	"\\\(\o\{1,3}\|[\"\\'\\?ntbrfva]\|u\x\{4}\|U\x\{8}\|x\x\x\)"
syn match dEscSequence	"\\&[^;& \t]\+;"
syn match dCharacter	"'[^']*'" contains=dEscSequence,dSpecialCharError
syn match dCharacter	"'\\''" contains=dEscSequence
syn match dCharacter	"'[^\\]'"

syn cluster dTokens add=dEscSequence,dCharacter

" Unicode characters
"
syn match dUnicode "\\u\d\{4\}"

" String.
"
syn region dString	start=+"+ end=+"[cwd]\=+ skip=+\\\\\|\\"+ contains=dEscSequence,@Spell
syn region dRawString	start=+`+ end=+`[cwd]\=+ contains=@Spell
syn region dRawString	start=+r"+ end=+"[cwd]\=+ contains=@Spell
syn region dHexString	start=+x"+ end=+"[cwd]\=+ contains=@Spell
syn region dDelimString	start=+q"\z(.\)+ end=+\z1"+ contains=@Spell
syn region dHereString	start=+q"\z(\I\i*\)\n+ end=+^\z1"+ contains=@Spell

" Nesting delimited string contents
"
syn region dNestParenString start=+(+ end=+)+ contained transparent contains=dNestParenString,@Spell
syn region dNestBrackString start=+\[+ end=+\]+ contained transparent contains=dNestBrackString,@Spell
syn region dNestAngleString start=+<+ end=+>+ contained transparent contains=dNestAngleString,@Spell
syn region dNestCurlyString start=+{+ end=+}+ contained transparent contains=dNestCurlyString,@Spell

" Nesting delimited strings
"
syn region dParenString	matchgroup=dParenString start=+q"(+ end=+)"+ contains=dNestParenString,@Spell
syn region dBrackString	matchgroup=dBrackString start=+q"\[+ end=+\]"+ contains=dNestBrackString,@Spell
syn region dAngleString	matchgroup=dAngleString start=+q"<+ end=+>"+ contains=dNestAngleString,@Spell
syn region dCurlyString	matchgroup=dCurlyString start=+q"{+ end=+}"+ contains=dNestCurlyString,@Spell

hi link dParenString dNestString
hi link dBrackString dNestString
hi link dAngleString dNestString
hi link dCurlyString dNestString

syn cluster dTokens add=dString,dRawString,dHexString,dDelimString,dNestString

" Token strings
"
syn region dNestTokenString start=+{+ end=+}+ contained contains=dNestTokenString,@dTokens
syn region dTokenString matchgroup=dTokenStringBrack transparent start=+q{+ end=+}+ contains=dNestTokenString,@dTokens

syn cluster dTokens add=dTokenString

" Numbers
"
syn case ignore

syn match dDec		display "\<\d[0-9_]*\(u\=l\=\|l\=u\=\)\>"

" Hex number
syn match dHex		display "\<0x[0-9a-f_]\+\(u\=l\=\|l\=u\=\)\>"

syn match dOctal	display "\<0[0-7_]\+\(u\=l\=\|l\=u\=\)\>"
" flag an octal number with wrong digits
syn match dOctalError	display "\<0[0-7_]*[89][0-9_]*"

" binary numbers
syn match dBinary	display "\<0b[01_]\+\(u\=l\=\|l\=u\=\)\>"

"floating point without the dot
syn match dFloat	display "\<\d[0-9_]*\(fi\=\|l\=i\)\>"
"floating point number, with dot, optional exponent
syn match dFloat	display "\<\d[0-9_]*\.[0-9_]*\(e[-+]\=[0-9_]\+\)\=[fl]\=i\="
"floating point number, starting with a dot, optional exponent
syn match dFloat	display "\(\.[0-9_]\+\)\(e[-+]\=[0-9_]\+\)\=[fl]\=i\=\>"
"floating point number, without dot, with exponent
"syn match dFloat	display "\<\d\+e[-+]\=\d\+[fl]\=\>"
syn match dFloat	display "\<\d[0-9_]*e[-+]\=[0-9_]\+[fl]\=\>"

"floating point without the dot
syn match dHexFloat	display "\<0x[0-9a-f_]\+\(fi\=\|l\=i\)\>"
"floating point number, with dot, optional exponent
syn match dHexFloat	display "\<0x[0-9a-f_]\+\.[0-9a-f_]*\(p[-+]\=[0-9_]\+\)\=[fl]\=i\="
"floating point number, without dot, with exponent
syn match dHexFloat	display "\<0x[0-9a-f_]\+p[-+]\=[0-9_]\+[fl]\=i\=\>"

syn cluster dTokens add=dDec,dHex,dOctal,dOctalError,dBinary,dFloat,dHexFloat

syn case match

" Pragma (preprocessor) support
" TODO: Highlight following Integer and optional Filespec.
syn region  dPragma start="#\s*\(line\>\)" skip="\\$" end="$"

" Block
"
syn region dBlock	start="{" end="}" transparent fold


" The default highlighting.
"
hi def link dBinary              Number
hi def link dDec                 Number
hi def link dHex                 Number
hi def link dOctal               Number
hi def link dFloat               Float
hi def link dHexFloat            Float
hi def link dDebug               Debug
hi def link dBranch              Conditional
hi def link dConditional         Conditional
hi def link dLabel               Label
hi def link dUserLabel           Label
hi def link dRepeat              Repeat
hi def link dExceptions          Exception
hi def link dAssert              Statement
hi def link dStatement           Statement
hi def link dScopeDecl           dStorageClass
hi def link dStorageClass        StorageClass
hi def link dBoolean             Boolean
hi def link dUnicode             Special
hi def link dTokenStringBrack    String
hi def link dHereString          String
hi def link dNestString          String
hi def link dDelimString         String
hi def link dRawString           String
hi def link dString              String
hi def link dHexString           String
hi def link dCharacter           Character
hi def link dEscSequence         SpecialChar
hi def link dSpecialCharError    Error
hi def link dOctalError          Error
hi def link dOperator            Operator
hi def link dOpOverload          Identifier
hi def link dConstant            Constant
hi def link dTypedef             Typedef
hi def link dEnum                Structure
hi def link dStructure           Structure
hi def link dTodo                Todo
hi def link dType                Type
hi def link dLineComment         Comment
hi def link dBlockComment        Comment
hi def link dNestedComment       Comment
hi def link dCommentError        Error
hi def link dNestedCommentError  Error
hi def link dCommentStartError   Error
hi def link dExternal            Include
hi def link dAnnotation          PreProc
hi def link dSharpBang           PreProc
hi def link dAttribute           StorageClass
hi def link dIdentifier          Identifier
hi def link dVersion             dStatement
hi def link dVersionIdentifier   Identifier
hi def link dScopeIdentifier     Identifier
hi def link dTraitsIdentifier    Identifier
hi def link dPragma              PreProc
hi def link dPragmaIdentifier    Identifier
hi def link dExtern              dExternal
hi def link dExternIdentifier    Identifier

" Marks contents of the asm statment body as special

syn match dAsmStatement "\<asm\>"
syn region dAsmBody start="asm[\n]*\s*{"hs=e+1 end="}"he=e-1 contains=dAsmStatement,dAsmOpCode,@dComment,DUserLabel

hi def link dAsmBody dUnicode
hi def link dAsmStatement dStatement
hi def link dAsmOpCode Identifier

syn keyword dAsmOpCode contained	aaa		aad		aam		aas
syn keyword dAsmOpCode contained	add		addpd		addps		addsd
syn keyword dAsmOpCode contained	and		andnpd		andnps		andpd
syn keyword dAsmOpCode contained	arpl		bound		bsf		bsr
syn keyword dAsmOpCode contained	bt		btc		btr		bts
syn keyword dAsmOpCode contained	call		bswap		andps		addss
syn keyword dAsmOpCode contained	cbw		cdq		clc		cld
syn keyword dAsmOpCode contained	cli		clts		cmc		cmova
syn keyword dAsmOpCode contained	cmovb		cmovbe		cmovc		cmove
syn keyword dAsmOpCode contained	cmovge		cmovl		cmovle		cmovna
syn keyword dAsmOpCode contained	cmovnae		cmovg		cmovae		clflush
syn keyword dAsmOpCode contained	cmovnb		cmovnbe		cmovnc		cmovne
syn keyword dAsmOpCode contained	cmovnge		cmovnl		cmovnle		cmovno
syn keyword dAsmOpCode contained	cmovns		cmovnz		cmovo		cmovp
syn keyword dAsmOpCode contained	cmovpo		cmovs		cmovz		cmp
syn keyword dAsmOpCode contained	cmppd		cmovpe		cmovnp		cmovng
syn keyword dAsmOpCode contained	cmpps		cmps		cmpsb		cmpsd
syn keyword dAsmOpCode contained	cmpsw		cmpxch8b	cmpxchg		comisd
syn keyword dAsmOpCode contained	cpuid		cvtdq2pd	cvtdq2ps	cvtpd2dq
syn keyword dAsmOpCode contained	cvtpd2ps	cvtpi2pd	cvtpi2ps	cvtps2dq
syn keyword dAsmOpCode contained	cvtps2pd	cvtpd2pi	comiss		cmpss
syn keyword dAsmOpCode contained	cvtps2pi	cvtsd2si	cvtsd2ss	cvtsi2sd
syn keyword dAsmOpCode contained	cvtss2sd	cvtss2si	cvttpd2dq	cvttpd2pi
syn keyword dAsmOpCode contained	cvttps2pi	cvttsd2si	cvttss2si	cwd
syn keyword dAsmOpCode contained	da		daa		das		db
syn keyword dAsmOpCode contained	dd		cwde		cvttps2dq	cvtsi2ss
syn keyword dAsmOpCode contained	de		dec		df		di
syn keyword dAsmOpCode contained	divpd		divps		divsd		divss
syn keyword dAsmOpCode contained	dq		ds		dt		dw
syn keyword dAsmOpCode contained	enter		f2xm1		fabs		fadd
syn keyword dAsmOpCode contained	faddp		emms		dl		div
syn keyword dAsmOpCode contained	fbld		fbstp		fchs		fclex
syn keyword dAsmOpCode contained	fcmovbe		fcmove		fcmovnb		fcmovnbe
syn keyword dAsmOpCode contained	fcmovnu		fcmovu		fcom		fcomi
syn keyword dAsmOpCode contained	fcomp		fcompp		fcos		fdecstp
syn keyword dAsmOpCode contained	fdisi		fcomip		fcmovne		fcmovb
syn keyword dAsmOpCode contained	fdiv		fdivp		fdivr		fdivrp
syn keyword dAsmOpCode contained	ffree		fiadd		ficom		ficomp
syn keyword dAsmOpCode contained	fidivr		fild		fimul		fincstp
syn keyword dAsmOpCode contained	fist		fistp		fisub		fisubr
syn keyword dAsmOpCode contained	fld		finit		fidiv		feni
syn keyword dAsmOpCode contained	fld1		fldcw		fldenv		fldl2e
syn keyword dAsmOpCode contained	fldlg2		fldln2		fldpi		fldz
syn keyword dAsmOpCode contained	fmulp		fnclex		fndisi		fneni
syn keyword dAsmOpCode contained	fnop		fnsave		fnstcw		fnstenv
syn keyword dAsmOpCode contained	fnstsw		fninit		fmul		fldl2t
syn keyword dAsmOpCode contained	fpatan		fprem		fprem1		fptan
syn keyword dAsmOpCode contained	frstor		fsave		fscale		fsetpm
syn keyword dAsmOpCode contained	fsincos		fsqrt		fst		fstcw
syn keyword dAsmOpCode contained	fstp		fstsw		fsub		fsubp
syn keyword dAsmOpCode contained	fsubr		fstenv		fsin		frndint
syn keyword dAsmOpCode contained	fsubrp		ftst		fucom		fucomi
syn keyword dAsmOpCode contained	fucomp		fucompp		fwait		fxam
syn keyword dAsmOpCode contained	fxrstor		fxsave		fxtract		fyl2x
syn keyword dAsmOpCode contained	hlt		idiv		imul		in
syn keyword dAsmOpCode contained	inc		fyl2xp1		fxch		fucomip
syn keyword dAsmOpCode contained	ins		insb		insd		insw
syn keyword dAsmOpCode contained	into		invd		invlpg		iret
syn keyword dAsmOpCode contained	ja		jae		jb		jbe
syn keyword dAsmOpCode contained	jcxz		je		jecxz		jg
syn keyword dAsmOpCode contained	jge		jc		iretd		int
syn keyword dAsmOpCode contained	jl		jle		jmp		jna
syn keyword dAsmOpCode contained	jnb		jnbe		jnc		jne
syn keyword dAsmOpCode contained	jnge		jnl		jnle		jno
syn keyword dAsmOpCode contained	jns		jnz		jo		jp
syn keyword dAsmOpCode contained	jpe		jnp		jng		jnae
syn keyword dAsmOpCode contained	jpo		js		jz		lahf
syn keyword dAsmOpCode contained	ldmxcsr		lds		lea		leave
syn keyword dAsmOpCode contained	lfence		lfs		lgdt		lgs
syn keyword dAsmOpCode contained	lldt		lmsw		lock		lods
syn keyword dAsmOpCode contained	lodsb		lidt		les		lar
syn keyword dAsmOpCode contained	lodsd		lodsw		loop		loope
syn keyword dAsmOpCode contained	loopnz		loopz		lsl		lss
syn keyword dAsmOpCode contained	maskmovdqu	maskmovq	maxpd		maxps
syn keyword dAsmOpCode contained	maxss		mfence		minpd		minps
syn keyword dAsmOpCode contained	minsd		maxsd		ltr		loopne
syn keyword dAsmOpCode contained	minss		mov		movapd		movaps
syn keyword dAsmOpCode contained	movdq2q		movdqa		movdqu		movhlps
syn keyword dAsmOpCode contained	movhps		movlhps		movlpd		movlps
syn keyword dAsmOpCode contained	movmskps	movntdq		movnti		movntpd
syn keyword dAsmOpCode contained	movntps		movmskpd	movhpd		movd
syn keyword dAsmOpCode contained	movntq		movq		movq2dq		movs
syn keyword dAsmOpCode contained	movsd		movss		movsw		movsx
syn keyword dAsmOpCode contained	movups		movzx		mul		mulpd
syn keyword dAsmOpCode contained	mulsd		mulss		neg		nop
syn keyword dAsmOpCode contained	not		mulps		movupd		movsb
syn keyword dAsmOpCode contained	or		orpd		orps		out
syn keyword dAsmOpCode contained	outsb		outsd		outsw		packssdw
syn keyword dAsmOpCode contained	packuswb	paddb		paddd		paddq
syn keyword dAsmOpCode contained	paddsw		paddusb		paddusw		paddw
syn keyword dAsmOpCode contained	pand		paddsb		packsswb	outs
syn keyword dAsmOpCode contained	pandn		pavgb		pavgw		pcmpeqb
syn keyword dAsmOpCode contained	pcmpeqw		pcmpgtb		pcmpgtd		pcmpgtw
syn keyword dAsmOpCode contained	pinsrw		pmaddwd		pmaxsw		pmaxub
syn keyword dAsmOpCode contained	pminub		pmovmskb	pmulhuw		pmulhw
syn keyword dAsmOpCode contained	pmullw		pminsw		pextrw		pcmpeqd
syn keyword dAsmOpCode contained	pmuludq		pop		popa		popad
syn keyword dAsmOpCode contained	popfd		por		prefetchnta	prefetcht0
syn keyword dAsmOpCode contained	prefetcht2	psadbw		pshufd		pshufhw
syn keyword dAsmOpCode contained	pshufw		pslld		pslldq		psllq
syn keyword dAsmOpCode contained	psllw		pshuflw		prefetcht1	popf
syn keyword dAsmOpCode contained	psrad		psraw		psrld		psrldq
syn keyword dAsmOpCode contained	psrlw		psubb		psubd		psubq
syn keyword dAsmOpCode contained	psubsw		psubusb		psubusw		psubw
syn keyword dAsmOpCode contained	punpckhdq	punpckhqdq	punpckhwd	punpcklbw
syn keyword dAsmOpCode contained	punpckldq	punpckhbw	psubsb		psrlq
syn keyword dAsmOpCode contained	punpcklqdq	punpcklwd	push		pusha
syn keyword dAsmOpCode contained	pushf		pushfd		pxor		rcl
syn keyword dAsmOpCode contained	rcpss		rcr		rdmsr		rdpmc
syn keyword dAsmOpCode contained	rep		repe		repne		repnz
syn keyword dAsmOpCode contained	repz		rdtsc		rcpps		pushad
syn keyword dAsmOpCode contained	ret		retf		rol		ror
syn keyword dAsmOpCode contained	rsqrtps		rsqrtss		sahf		sal
syn keyword dAsmOpCode contained	sbb		scas		scasb		scasd
syn keyword dAsmOpCode contained	seta		setae		setb		setbe
syn keyword dAsmOpCode contained	setc		scasw		sar		rsm
syn keyword dAsmOpCode contained	sete		setg		setge		setl
syn keyword dAsmOpCode contained	setna		setnae		setnb		setnbe
syn keyword dAsmOpCode contained	setne		setng		setnge		setnl
syn keyword dAsmOpCode contained	setno		setnp		setns		setnz
syn keyword dAsmOpCode contained	seto		setnle		setnc		setle
syn keyword dAsmOpCode contained	setp		setpe		setpo		sets
syn keyword dAsmOpCode contained	sfence		sgdt		shl		shld
syn keyword dAsmOpCode contained	shrd		shufpd		shufps		sidt
syn keyword dAsmOpCode contained	smsw		sqrtpd		sqrtps		sqrtsd
syn keyword dAsmOpCode contained	sqrtss		sldt		shr		setz
syn keyword dAsmOpCode contained	stc		std		sti		stmxcsr
syn keyword dAsmOpCode contained	stosb		stosd		stosw		str
syn keyword dAsmOpCode contained	subpd		subps		subsd		subss
syn keyword dAsmOpCode contained	sysexit		test		ucomisd		ucomiss
syn keyword dAsmOpCode contained	ud2		sysenter	sub		stos
syn keyword dAsmOpCode contained	unpckhpd	unpckhps	unpcklpd	unpcklps
syn keyword dAsmOpCode contained	verw		wbinvd		wrmsr		xadd
syn keyword dAsmOpCode contained	xchg		xlatb		xor		xorpd
syn keyword dAsmOpCode contained	xorps		pfrcpit1	pfmin		movddup
syn keyword dAsmOpCode contained	addsubpd	addsubps	fisttp		haddps
syn keyword dAsmOpCode contained	hsubpd		hsubps		lddqu		monitor
syn keyword dAsmOpCode contained	haddpd		xlat		wait		verr
syn keyword dAsmOpCode contained	movshdup	movsldup	mwait		pfcmpeq
syn keyword dAsmOpCode contained	pavgusb		pf2id		pfacc		pfadd
syn keyword dAsmOpCode contained	pfcmpge		pfcmpgt		pfmax		pfmul
syn keyword dAsmOpCode contained	pfnacc		pfpnacc		pfrcp		pfrcpit1
syn keyword dAsmOpCode contained	pfrsqit1	pfrsqrt		pfsub		pfsubr
syn keyword dAsmOpCode contained	pmulhrw 	pswapd		syscall		sysret
syn keyword dAsmOpCode contained	vpmuldq		xgetbv		cmpxchg8b	cmpxchg16b
syn keyword dAsmOpCode contained	pabsb		pabsd		pabsw		palignr
syn keyword dAsmOpCode contained	phaddd		phaddsw		phaddw		phsubd
syn keyword dAsmOpCode contained	phsubsw		phsubw		pmaddubsw	pmulhrsw
syn keyword dAsmOpCode contained	pshufb		psignb		psignd		psignw
syn keyword dAsmOpCode contained	popfq		pushfq		blendpd		blendps
syn keyword dAsmOpCode contained	blendvpd	blendvps	extractps	insertps
syn keyword dAsmOpCode contained	movntdqa	mpsadbw		packusdw	pblendvb
syn keyword dAsmOpCode contained	pblendw		pcmpeqq		pextrb		pextrd
syn keyword dAsmOpCode contained	pextrq		phminposuw	pinsrb		pinsrd
syn keyword dAsmOpCode contained	pinsrq		pmaxsb		pmaxsd		pmaxud
syn keyword dAsmOpCode contained	pmaxuw		pminsb		pminsd		pminud
syn keyword dAsmOpCode contained	pminuw		pmulld		ptest		roundpd
syn keyword dAsmOpCode contained	roundps		roundsd		roundss		pmuldq
syn keyword dAsmOpCode contained	pmovsxbd	pmovsxdq	pmovzxbq	pmovzxdq
syn keyword dAsmOpCode contained	pmovsxbq	pmovsxwd	pmovzxbq	pmovzxwd
syn keyword dAsmOpCode contained	pmovsxbw	pmovsxwq	pmovzxbw	pmovzxwq
syn keyword dAsmOpCode contained	crc32		pcmpestri	pcmpestrm	pcmpgtq
syn keyword dAsmOpCode contained	pcmpistri	pcmpistrm	popcnt		pi2fd
syn keyword dAsmOpCode contained	adc

let &cpo = s:cpo_save
unlet s:cpo_save
