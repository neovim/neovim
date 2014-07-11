" Vim syntax file
" Language:     IA-64 (Itanium) assembly language
" Maintainer:   Parth Malwankar <pmalwankar@yahoo.com>
" URL:		http://www.geocities.com/pmalwankar (Home Page with link to my Vim page)
"		http://www.geocities.com/pmalwankar/vim.htm (for VIM)
" File Version: 0.7
" Last Change:  2006 Sep 08

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif


"ignore case for assembly
syn case ignore

"  Identifier Keyword characters (defines \k)
if version >= 600
	setlocal iskeyword=@,48-57,#,$,.,:,?,@-@,_,~
else
	set iskeyword=@,48-57,#,$,.,:,?,@-@,_,~
endif

syn sync minlines=5

" Read the MASM syntax to start with
" This is needed as both IA-64 as well as IA-32 instructions are supported
source <sfile>:p:h/masm.vim

syn region ia64Comment start="//" end="$" contains=ia64Todo
syn region ia64Comment start="/\*" end="\*/" contains=ia64Todo

syn match ia64Identifier	"[a-zA-Z_$][a-zA-Z0-9_$]*"
syn match ia64Directive		"\.[a-zA-Z_$][a-zA-Z_$.]\+"
syn match ia64Label		"[a-zA-Z_$.][a-zA-Z0-9_$.]*\s\=:\>"he=e-1
syn match ia64Label		"[a-zA-Z_$.][a-zA-Z0-9_$.]*\s\=::\>"he=e-2
syn match ia64Label		"[a-zA-Z_$.][a-zA-Z0-9_$.]*\s\=#\>"he=e-1
syn region ia64string		start=+L\="+ skip=+\\\\\|\\"+ end=+"+
syn match ia64Octal		"0[0-7_]*\>"
syn match ia64Binary		"0[bB][01_]*\>"
syn match ia64Hex		"0[xX][0-9a-fA-F_]*\>"
syn match ia64Decimal		"[1-9_][0-9_]*\>"
syn match ia64Float		"[0-9_]*\.[0-9_]*\([eE][+-]\=[0-9_]*\)\=\>"

"simple instructions
syn keyword ia64opcode add adds addl addp4 alloc and andcm cover epc
syn keyword ia64opcode fabs fand fandcm fc flushrs fneg fnegabs for
syn keyword ia64opcode fpabs fpack fpneg fpnegabs fselect fand fabdcm
syn keyword ia64opcode fc fwb fxor loadrs movl mux1 mux2 or padd4
syn keyword ia64opcode pavgsub1 pavgsub2 popcnt psad1 pshl2 pshl4 pshladd2
syn keyword ia64opcode pshradd2 psub4 rfi rsm rum shl shladd shladdp4
syn keyword ia64opcode shrp ssm sub sum sync.i tak thash
syn keyword ia64opcode tpa ttag xor

"put to override these being recognized as floats. They are orignally from masm.vim
"put here to avoid confusion with float
syn match   ia64Directive       "\.186"
syn match   ia64Directive       "\.286"
syn match   ia64Directive       "\.286c"
syn match   ia64Directive       "\.286p"
syn match   ia64Directive       "\.287"
syn match   ia64Directive       "\.386"
syn match   ia64Directive       "\.386c"
syn match   ia64Directive       "\.386p"
syn match   ia64Directive       "\.387"
syn match   ia64Directive       "\.486"
syn match   ia64Directive       "\.486c"
syn match   ia64Directive       "\.486p"
syn match   ia64Directive       "\.8086"
syn match   ia64Directive       "\.8087"



"delimiters
syn match ia64delimiter ";;"

"operators
syn match ia64operators "[\[\]()#,]"
syn match ia64operators "\(+\|-\|=\)"

"TODO
syn match ia64Todo      "\(TODO\|XXX\|FIXME\|NOTE\)"

"What follows is a long list of regular expressions for parsing the
"ia64 instructions that use many completers

"br
syn match ia64opcode "br\(\(\.\(cond\|call\|ret\|ia\|cloop\|ctop\|cexit\|wtop\|wexit\)\)\=\(\.\(spnt\|dpnt\|sptk\|dptk\)\)\=\(\.few\|\.many\)\=\(\.clr\)\=\)\=\>"
"break
syn match ia64opcode "break\(\.[ibmfx]\)\=\>"
"brp
syn match ia64opcode "brp\(\.\(sptk\|dptk\|loop\|exit\)\)\(\.imp\)\=\>"
syn match ia64opcode "brp\.ret\(\.\(sptk\|dptk\)\)\{1}\(\.imp\)\=\>"
"bsw
syn match ia64opcode "bsw\.[01]\>"
"chk
syn match ia64opcode "chk\.\(s\(\.[im]\)\=\)\>"
syn match ia64opcode "chk\.a\.\(clr\|nc\)\>"
"clrrrb
syn match ia64opcode "clrrrb\(\.pr\)\=\>"
"cmp/cmp4
syn match ia64opcode "cmp4\=\.\(eq\|ne\|l[te]\|g[te]\|[lg]tu\|[lg]eu\)\(\.unc\)\=\>"
syn match ia64opcode "cmp4\=\.\(eq\|[lgn]e\|[lg]t\)\.\(\(or\(\.andcm\|cm\)\=\)\|\(and\(\(\.or\)\=cm\)\=\)\)\>"
"cmpxchg
syn match ia64opcode "cmpxchg[1248]\.\(acq\|rel\)\(\.nt1\|\.nta\)\=\>"
"czx
syn match ia64opcode "czx[12]\.[lr]\>"
"dep
syn match ia64opcode "dep\(\.z\)\=\>"
"extr
syn match ia64opcode "extr\(\.u\)\=\>"
"fadd
syn match ia64opcode "fadd\(\.[sd]\)\=\(\.s[0-3]\)\=\>"
"famax/famin
syn match ia64opcode "fa\(max\|min\)\(\.s[0-3]\)\=\>"
"fchkf/fmax/fmin
syn match ia64opcode "f\(chkf\|max\|min\)\(\.s[0-3]\)\=\>"
"fclass
syn match ia64opcode "fclass\(\.n\=m\)\(\.unc\)\=\>"
"fclrf/fpamax
syn match ia64opcode "f\(clrf\|pamax\|pamin\)\(\.s[0-3]\)\=\>"
"fcmp
syn match ia64opcode "fcmp\.\(n\=[lg][te]\|n\=eq\|\(un\)\=ord\)\(\.unc\)\=\(\.s[0-3]\)\=\>"
"fcvt/fcvt.xf/fcvt.xuf.pc.sf
syn match ia64opcode "fcvt\.\(\(fxu\=\(\.trunc\)\=\(\.s[0-3]\)\=\)\|\(xf\|xuf\(\.[sd]\)\=\(\.s[0-3]\)\=\)\)\>"
"fetchadd
syn match ia64opcode "fetchadd[48]\.\(acq\|rel\)\(\.nt1\|\.nta\)\=\>"
"fma/fmpy/fms
syn match ia64opcode "fm\([as]\|py\)\(\.[sd]\)\=\(\.s[0-3]\)\=\>"
"fmerge/fpmerge
syn match ia64opcode "fp\=merge\.\(ns\|se\=\)\>"
"fmix
syn match ia64opcode "fmix\.\(lr\|[lr]\)\>"
"fnma/fnorm/fnmpy
syn match ia64opcode "fn\(ma\|mpy\|orm\)\(\.[sd]\)\=\(\.s[0-3]\)\=\>"
"fpcmp
syn match ia64opcode "fpcmp\.\(n\=[lg][te]\|n\=eq\|\(un\)\=ord\)\(\.s[0-3]\)\=\>"
"fpcvt
syn match ia64opcode "fpcvt\.fxu\=\(\(\.trunc\)\=\(\.s[0-3]\)\=\)\>"
"fpma/fpmax/fpmin/fpmpy/fpms/fpnma/fpnmpy/fprcpa/fpsqrta
syn match ia64opcode "fp\(max\=\|min\|n\=mpy\|ms\|nma\|rcpa\|sqrta\)\(\.s[0-3]\)\=\>"
"frcpa/frsqrta
syn match ia64opcode "fr\(cpa\|sqrta\)\(\.s[0-3]\)\=\>"
"fsetc/famin/fchkf
syn match ia64opcode "f\(setc\|amin\|chkf\)\(\.s[0-3]\)\=\>"
"fsub
syn match ia64opcode "fsub\(\.[sd]\)\=\(\.s[0-3]\)\=\>"
"fswap
syn match ia64opcode "fswap\(\.n[lr]\=\)\=\>"
"fsxt
syn match ia64opcode "fsxt\.[lr]\>"
"getf
syn match ia64opcode "getf\.\([sd]\|exp\|sig\)\>"
"invala
syn match ia64opcode "invala\(\.[ae]\)\=\>"
"itc/itr
syn match ia64opcode "it[cr]\.[id]\>"
"ld
syn match ia64opcode "ld[1248]\>\|ld[1248]\(\.\(sa\=\|a\|c\.\(nc\|clr\(\.acq\)\=\)\|acq\|bias\)\)\=\(\.nt[1a]\)\=\>"
syn match ia64opcode "ld8\.fill\(\.nt[1a]\)\=\>"
"ldf
syn match ia64opcode "ldf[sde8]\(\(\.\(sa\=\|a\|c\.\(nc\|clr\)\)\)\=\(\.nt[1a]\)\=\)\=\>"
syn match ia64opcode "ldf\.fill\(\.nt[1a]\)\=\>"
"ldfp
syn match ia64opcode "ldfp[sd8]\(\(\.\(sa\=\|a\|c\.\(nc\|clr\)\)\)\=\(\.nt[1a]\)\=\)\=\>"
"lfetch
syn match ia64opcode "lfetch\(\.fault\(\.excl\)\=\|\.excl\)\=\(\.nt[12a]\)\=\>"
"mf
syn match ia64opcode "mf\(\.a\)\=\>"
"mix
syn match ia64opcode "mix[124]\.[lr]\>"
"mov
syn match ia64opcode "mov\(\.[im]\)\=\>"
syn match ia64opcode "mov\(\.ret\)\=\(\(\.sptk\|\.dptk\)\=\(\.imp\)\=\)\=\>"
"nop
syn match ia64opcode "nop\(\.[ibmfx]\)\=\>"
"pack
syn match ia64opcode "pack\(2\.[su]ss\|4\.sss\)\>"
"padd //padd4 added to keywords
syn match ia64opcode "padd[12]\(\.\(sss\|uus\|uuu\)\)\=\>"
"pavg
syn match ia64opcode "pavg[12]\(\.raz\)\=\>"
"pcmp
syn match ia64opcode "pcmp[124]\.\(eq\|gt\)\>"
"pmax/pmin
syn match ia64opcode "pm\(ax\|in\)\(\(1\.u\)\|2\)\>"
"pmpy
syn match ia64opcode "pmpy2\.[rl]\>"
"pmpyshr
syn match ia64opcode "pmpyshr2\(\.u\)\=\>"
"probe
syn match ia64opcode "probe\.[rw]\>"
syn match ia64opcode "probe\.\(\(r\|w\|rw\)\.fault\)\>"
"pshr
syn match ia64opcode "pshr[24]\(\.u\)\=\>"
"psub
syn match ia64opcode "psub[12]\(\.\(sss\|uu[su]\)\)\=\>"
"ptc
syn match ia64opcode "ptc\.\(l\|e\|ga\=\)\>"
"ptr
syn match ia64opcode "ptr\.\(d\|i\)\>"
"setf
syn match ia64opcode "setf\.\(s\|d\|exp\|sig\)\>"
"shr
syn match ia64opcode "shr\(\.u\)\=\>"
"srlz
syn match ia64opcode "srlz\(\.[id]\)\>"
"st
syn match ia64opcode "st[1248]\(\.rel\)\=\(\.nta\)\=\>"
syn match ia64opcode "st8\.spill\(\.nta\)\=\>"
"stf
syn match ia64opcode "stf[1248]\(\.nta\)\=\>"
syn match ia64opcode "stf\.spill\(\.nta\)\=\>"
"sxt
syn match ia64opcode "sxt[124]\>"
"tbit/tnat
syn match ia64opcode "t\(bit\|nat\)\(\.nz\|\.z\)\=\(\.\(unc\|or\(\.andcm\|cm\)\=\|and\(\.orcm\|cm\)\=\)\)\=\>"
"unpack
syn match ia64opcode "unpack[124]\.[lh]\>"
"xchq
syn match ia64opcode "xchg[1248]\(\.nt[1a]\)\=\>"
"xma/xmpy
syn match ia64opcode "xm\(a\|py\)\.[lh]u\=\>"
"zxt
syn match ia64opcode "zxt[124]\>"


"The regex for different ia64 registers are given below

"limits the rXXX and fXXX and cr suffix in the range 0-127
syn match ia64registers "\([fr]\|cr\)\([0-9]\|[1-9][0-9]\|1[0-1][0-9]\|12[0-7]\)\{1}\>"
"branch ia64registers
syn match ia64registers "b[0-7]\>"
"predicate ia64registers
syn match ia64registers "p\([0-9]\|[1-5][0-9]\|6[0-3]\)\>"
"application ia64registers
syn match ia64registers "ar\.\(fpsr\|mat\|unat\|rnat\|pfs\|bsp\|bspstore\|rsc\|lc\|ec\|ccv\|itc\|k[0-7]\)\>"
"ia32 AR's
syn match ia64registers "ar\.\(eflag\|fcr\|csd\|ssd\|cflg\|fsr\|fir\|fdr\)\>"
"sp/gp/pr/pr.rot/rp
syn keyword ia64registers sp gp pr pr.rot rp ip tp
"in/out/local
syn match ia64registers "\(in\|out\|loc\)\([0-9]\|[1-8][0-9]\|9[0-5]\)\>"
"argument ia64registers
syn match ia64registers "farg[0-7]\>"
"return value ia64registers
syn match ia64registers "fret[0-7]\>"
"psr
syn match ia64registers "psr\(\.\(l\|um\)\)\=\>"
"cr
syn match ia64registers "cr\.\(dcr\|itm\|iva\|pta\|ipsr\|isr\|ifa\|iip\|itir\|iipa\|ifs\|iim\|iha\|lid\|ivr\|tpr\|eoi\|irr[0-3]\|itv\|pmv\|lrr[01]\|cmcv\)\>"
"Indirect registers
syn match ia64registers "\(cpuid\|dbr\|ibr\|pkr\|pmc\|pmd\|rr\|itr\|dtr\)\>"
"MUX permutations for 8-bit elements
syn match ia64registers "\(@rev\|@mix\|@shuf\|@alt\|@brcst\)\>"
"floating point classes
syn match ia64registers "\(@nat\|@qnan\|@snan\|@pos\|@neg\|@zero\|@unorm\|@norm\|@inf\)\>"
"link relocation operators
syn match ia64registers "\(@\(\(\(gp\|sec\|seg\|image\)rel\)\|ltoff\|fptr\|ptloff\|ltv\|section\)\)\>"

"Data allocation syntax
syn match ia64data "data[1248]\(\(\(\.ua\)\=\(\.msb\|\.lsb\)\=\)\|\(\(\.msb\|\.lsb\)\=\(\.ua\)\=\)\)\=\>"
syn match ia64data "real\([48]\|1[06]\)\(\(\(\.ua\)\=\(\.msb\|\.lsb\)\=\)\|\(\(\.msb\|\.lsb\)\=\(\.ua\)\=\)\)\=\>"
syn match ia64data "stringz\=\(\(\(\.ua\)\=\(\.msb\|\.lsb\)\=\)\|\(\(\.msb\|\.lsb\)\=\(\.ua\)\=\)\)\=\>"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_ia64_syn_inits")
	if version < 508
		let did_ia64_syn_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
	endif

	"put masm groups with our groups
	HiLink masmOperator	ia64operator
	HiLink masmDirective	ia64Directive
	HiLink masmOpcode	ia64Opcode
	HiLink masmIdentifier	ia64Identifier
	HiLink masmFloat	ia64Float

	"ia64 specific stuff
	HiLink ia64Label	Define
	HiLink ia64Comment	Comment
	HiLink ia64Directive	Type
	HiLink ia64opcode	Statement
	HiLink ia64registers	Operator
	HiLink ia64string	String
	HiLink ia64Hex		Number
	HiLink ia64Binary	Number
	HiLink ia64Octal	Number
	HiLink ia64Float	Float
	HiLink ia64Decimal	Number
	HiLink ia64Identifier	Identifier
	HiLink ia64data		Type
	HiLink ia64delimiter	Delimiter
	HiLink ia64operator	Operator
	HiLink ia64Todo		Todo

	delcommand HiLink
endif

let b:current_syntax = "ia64"

" vim: ts=8 sw=2
