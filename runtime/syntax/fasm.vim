" Vim syntax file
" Language:	Flat Assembler (FASM)
" Maintainer:	Ron Aaron <ron@ronware.org>
" Last Change:	2012/02/13
" Vim URL:	http://www.vim.org/lang.html
" FASM Home:	http://flatassembler.net/
" FASM Version: 1.56

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword=a-z,A-Z,48-57,.,_
setlocal isident=a-z,A-Z,48-57,.,_
syn case ignore

syn keyword fasmRegister	ah al ax bh bl bp bx ch cl cr0 cr1 cr2 cr3 cr4 cr5 cr6
syn keyword fasmRegister	cr7 cs cx dh di dl dr0 dr1 dr2 dr3 dr4 dr5 dr6 dr7 ds dx
syn keyword fasmRegister	eax ebp ebx ecx edi edx es esi esp fs gs mm0 mm1 mm2 mm3
syn keyword fasmRegister	mm4 mm5 mm6 mm7 si sp ss st st0 st1 st2 st3 st4 st5 st6
syn keyword fasmRegister	st7 tr0 tr1 tr2 tr3 tr4 tr5 tr6 tr7 xmm0 xmm1 xmm2 xmm3
syn keyword fasmRegister	xmm4 xmm5 xmm6 xmm7
syn keyword fasmAddressSizes 	byte dqword dword fword pword qword tword word
syn keyword fasmDataDirectives 	db dd df dp dq dt du dw file rb rd rf rp rq rt rw
syn keyword fasmInstr 	aaa aad aam aas adc add addpd addps addsd addss addsubpd
syn keyword fasmInstr	addsubps and andnpd andnps andpd andps arpl bound bsf bsr
syn keyword fasmInstr	bswap bt btc btr bts call cbw cdq clc cld clflush cli clts
syn keyword fasmInstr	cmc cmova cmovae cmovb cmovbe cmovc cmove cmovg cmovge cmovl
syn keyword fasmInstr	cmovle cmovna cmovnae cmovnb cmovnbe cmovnc cmovne cmovng
syn keyword fasmInstr	cmovnge cmovnl cmovnle cmovno cmovnp cmovns cmovnz cmovo cmovp
syn keyword fasmInstr	cmovpe cmovpo cmovs cmovz cmp cmpeqpd cmpeqps cmpeqsd cmpeqss
syn keyword fasmInstr	cmplepd cmpleps cmplesd cmpless cmpltpd cmpltps cmpltsd cmpltss
syn keyword fasmInstr	cmpneqpd cmpneqps cmpneqsd cmpneqss cmpnlepd cmpnleps cmpnlesd
syn keyword fasmInstr	cmpnless cmpnltpd cmpnltps cmpnltsd cmpnltss cmpordpd cmpordps
syn keyword fasmInstr	cmpordsd cmpordss cmppd cmpps cmps cmpsb cmpsd cmpss cmpsw
syn keyword fasmInstr	cmpunordpd cmpunordps cmpunordsd cmpunordss cmpxchg cmpxchg8b
syn keyword fasmInstr	comisd comiss cpuid cvtdq2pd cvtdq2ps cvtpd2dq cvtpd2pi cvtpd2ps
syn keyword fasmInstr	cvtpi2pd cvtpi2ps cvtps2dq cvtps2pd cvtps2pi cvtsd2si cvtsd2ss
syn keyword fasmInstr	cvtsi2sd cvtsi2ss cvtss2sd cvtss2si cvttpd2dq cvttpd2pi cvttps2dq
syn keyword fasmInstr	cvttps2pi cvttsd2si cvttss2si cwd cwde daa das data dec div
syn keyword fasmInstr	divpd divps divsd divss else emms end enter extrn f2xm1 fabs
syn keyword fasmInstr	fadd faddp fbld fbstp fchs fclex fcmovb fcmovbe fcmove fcmovnb
syn keyword fasmInstr	fcmovnbe fcmovne fcmovnu fcmovu fcom fcomi fcomip fcomp fcompp
syn keyword fasmInstr	fcos fdecstp fdisi fdiv fdivp fdivr fdivrp femms feni ffree
syn keyword fasmInstr	ffreep fiadd ficom ficomp fidiv fidivr fild fimul fincstp
syn keyword fasmInstr	finit fist fistp fisttp fisub fisubr fld fld1 fldcw fldenv
syn keyword fasmInstr	fldl2e fldl2t fldlg2 fldln2 fldpi fldz fmul fmulp fnclex fndisi
syn keyword fasmInstr	fneni fninit fnop fnsave fnstcw fnstenv fnstsw fpatan fprem
syn keyword fasmInstr	fprem1 fptan frndint frstor frstpm fsave fscale fsetpm fsin
syn keyword fasmInstr	fsincos fsqrt fst fstcw fstenv fstp fstsw fsub fsubp fsubr
syn keyword fasmInstr	fsubrp ftst fucom fucomi fucomip fucomp fucompp fwait fxam
syn keyword fasmInstr	fxch fxrstor fxsave fxtract fyl2x fyl2xp1 haddpd haddps heap
syn keyword fasmInstr	hlt hsubpd hsubps idiv if imul in inc ins insb insd insw int
syn keyword fasmInstr	int3 into invd invlpg iret iretd iretw ja jae jb jbe jc jcxz
syn keyword fasmInstr	je jecxz jg jge jl jle jmp jna jnae jnb jnbe jnc jne jng jnge
syn keyword fasmInstr	jnl jnle jno jnp jns jnz jo jp jpe jpo js jz lahf lar lddqu
syn keyword fasmInstr	ldmxcsr lds lea leave les lfence lfs lgdt lgs lidt lldt lmsw
syn keyword fasmInstr	load loadall286 loadall386 lock lods lodsb lodsd lodsw loop
syn keyword fasmInstr	loopd loope looped loopew loopne loopned loopnew loopnz loopnzd
syn keyword fasmInstr	loopnzw loopw loopz loopzd loopzw lsl lss ltr maskmovdqu maskmovq
syn keyword fasmInstr	maxpd maxps maxsd maxss mfence minpd minps minsd minss monitor
syn keyword fasmInstr	mov movapd movaps movd movddup movdq2q movdqa movdqu movhlps
syn keyword fasmInstr	movhpd movhps movlhps movlpd movlps movmskpd movmskps movntdq
syn keyword fasmInstr	movnti movntpd movntps movntq movq movq2dq movs movsb movsd
syn keyword fasmInstr	movshdup movsldup movss movsw movsx movupd movups movzx mul
syn keyword fasmInstr	mulpd mulps mulsd mulss mwait neg nop not or org orpd orps
syn keyword fasmInstr	out outs outsb outsd outsw packssdw packsswb packuswb paddb
syn keyword fasmInstr	paddd paddq paddsb paddsw paddusb paddusw paddw pand pandn
syn keyword fasmInstr	pause pavgb pavgusb pavgw pcmpeqb pcmpeqd pcmpeqw pcmpgtb
syn keyword fasmInstr	pcmpgtd pcmpgtw pextrw pf2id pf2iw pfacc pfadd pfcmpeq pfcmpge
syn keyword fasmInstr	pfcmpgt pfmax pfmin pfmul pfnacc pfpnacc pfrcp pfrcpit1 pfrcpit2
syn keyword fasmInstr	pfrsqit1 pfrsqrt pfsub pfsubr pi2fd pi2fw pinsrw pmaddwd pmaxsw
syn keyword fasmInstr	pmaxub pminsw pminub pmovmskb pmulhrw pmulhuw pmulhw pmullw
syn keyword fasmInstr	pmuludq pop popa popad popaw popd popf popfd popfw popw por
syn keyword fasmInstr	prefetch prefetchnta prefetcht0 prefetcht1 prefetcht2 prefetchw
syn keyword fasmInstr	psadbw pshufd pshufhw pshuflw pshufw pslld pslldq psllq psllw
syn keyword fasmInstr	psrad psraw psrld psrldq psrlq psrlw psubb psubd psubq psubsb
syn keyword fasmInstr	psubsw psubusb psubusw psubw pswapd punpckhbw punpckhdq punpckhqdq
syn keyword fasmInstr	punpckhwd punpcklbw punpckldq punpcklqdq punpcklwd push pusha
syn keyword fasmInstr	pushad pushaw pushd pushf pushfd pushfw pushw pxor rcl rcpps
syn keyword fasmInstr	rcpss rcr rdmsr rdpmc rdtsc rep repe repne repnz repz ret
syn keyword fasmInstr	retd retf retfd retfw retn retnd retnw retw rol ror rsm rsqrtps
syn keyword fasmInstr	rsqrtss sahf sal salc sar sbb scas scasb scasd scasw seta
syn keyword fasmInstr	setae setalc setb setbe setc sete setg setge setl setle setna
syn keyword fasmInstr	setnae setnb setnbe setnc setne setng setnge setnl setnle
syn keyword fasmInstr	setno setnp setns setnz seto setp setpe setpo sets setz sfence
syn keyword fasmInstr	sgdt shl shld shr shrd shufpd shufps sidt sldt smsw sqrtpd
syn keyword fasmInstr	sqrtps sqrtsd sqrtss stc std sti stmxcsr store stos stosb
syn keyword fasmInstr	stosd stosw str sub subpd subps subsd subss sysenter sysexit
syn keyword fasmInstr	test ucomisd ucomiss ud2 unpckhpd unpckhps unpcklpd unpcklps
syn keyword fasmInstr	verr verw wait wbinvd wrmsr xadd xchg xlat xlatb xor xorpd
syn keyword fasmPreprocess 	common equ fix forward include local macro purge restore
syn keyword fasmPreprocess	reverse struc
syn keyword fasmDirective 	align binary code coff console discardable display dll
syn keyword fasmDirective	elf entry executable export extern far fixups format gui
syn keyword fasmDirective	import label ms mz native near notpageable pe public readable
syn keyword fasmDirective	repeat resource section segment shareable stack times
syn keyword fasmDirective	use16 use32 virtual wdm writable writeable
syn keyword fasmOperator 	as at defined eq eqtype from mod on ptr rva used

syn match	fasmNumericOperator	"[+-/*]"
syn match	fasmLogicalOperator	"[=|&~<>]\|<=\|>=\|<>"
" numbers
syn match	fasmBinaryNumber	"\<[01]\+b\>"
syn match	fasmHexNumber		"\<\d\x*h\>"
syn match	fasmHexNumber		"\<\(0x\|$\)\x*\>"
syn match	fasmFPUNumber		"\<\d\+\(\.\d*\)\=\(e[-+]\=\d*\)\=\>"
syn match	fasmOctalNumber		"\<\(0\o\+o\=\|\o\+o\)\>"
syn match	fasmDecimalNumber	"\<\(0\|[1-9]\d*\)\>"
syn region	fasmComment		start=";" end="$"
syn region	fasmString		start="\"" end="\"\|$"
syn region	fasmString		start="'" end="'\|$"
syn match	fasmSymbol		"[()|\[\]:]"
syn match	fasmSpecial		"[#?%$,]"
syn match	fasmLabel		"^\s*[^; \t]\+:"

hi def link	fasmAddressSizes	type
hi def link	fasmNumericOperator	fasmOperator
hi def link	fasmLogicalOperator	fasmOperator

hi def link	fasmBinaryNumber	fasmNumber
hi def link	fasmHexNumber		fasmNumber
hi def link	fasmFPUNumber		fasmNumber
hi def link	fasmOctalNumber		fasmNumber
hi def link	fasmDecimalNumber	fasmNumber

hi def link	fasmSymbols		fasmRegister
hi def link	fasmPreprocess		fasmDirective

"  link to standard syn groups so the 'colorschemes' work:
hi def link	fasmOperator operator
hi def link	fasmComment  comment
hi def link	fasmDirective	preproc
hi def link	fasmRegister  type
hi def link	fasmNumber   constant
hi def link	fasmSymbol structure
hi def link	fasmString  String
hi def link	fasmSpecial	special
hi def link	fasmInstr keyword
hi def link	fasmLabel label
hi def link	fasmPrefix preproc
let b:current_syntax = "fasm"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sw=8 :
