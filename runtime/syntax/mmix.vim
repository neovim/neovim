" Vim syntax file
" Language:	MMIX
" Maintainer:	Dirk Hüsken, <huesken@informatik.uni-tuebingen.de>
" Last Change:	2012 Jun 01
" 		(Dominique Pelle added @Spell)
" Filenames:	*.mms
" URL: http://homepages.uni-tuebingen.de/student/dirk.huesken/vim/syntax/mmix.vim

" Limitations:	Comments must start with either % or //
"		(preferably %, Knuth-Style)

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

" MMIX data types
syn keyword mmixType	byte wyde tetra octa

" different literals...
syn match decNumber		"[0-9]*"
syn match octNumber		"0[0-7][0-7]\+"
syn match hexNumber		"#[0-9a-fA-F]\+"
syn region mmixString		start=+"+ skip=+\\"+ end=+"+ contains=@Spell
syn match mmixChar		"'.'"

" ...and more special MMIX stuff
syn match mmixAt		"@"
syn keyword mmixSegments	Data_Segment Pool_Segment Stack_Segment

syn match mmixIdentifier	"[a-z_][a-z0-9_]*"

" labels (for branches etc)
syn match mmixLabel		"^[a-z0-9_:][a-z0-9_]*"
syn match mmixLabel		"[0-9][HBF]"

" pseudo-operations
syn keyword mmixPseudo		is loc greg

" comments
syn match mmixComment		"%.*" contains=@Spell
syn match mmixComment		"//.*" contains=@Spell
syn match mmixComment		"^\*.*" contains=@Spell


syn keyword mmixOpcode	trap fcmp fun feql fadd fix fsub fixu
syn keyword mmixOpcode	fmul fcmpe fune feqle fdiv fsqrt frem fint

syn keyword mmixOpcode	floti flotui sfloti sflotui i
syn keyword mmixOpcode	muli mului divi divui
syn keyword mmixOpcode	addi addui subi subui
syn keyword mmixOpcode	2addui 4addui 8addui 16addui
syn keyword mmixOpcode	cmpi cmpui negi negui
syn keyword mmixOpcode	sli slui sri srui
syn keyword mmixOpcode	bnb bzb bpb bodb
syn keyword mmixOpcode	bnnb bnzb bnpb bevb
syn keyword mmixOpcode	pbnb pbzb pbpb pbodb
syn keyword mmixOpcode	pbnnb pbnzb pbnpb pbevb
syn keyword mmixOpcode	csni cszi cspi csodi
syn keyword mmixOpcode	csnni csnzi csnpi csevi
syn keyword mmixOpcode	zsni zszi zspi zsodi
syn keyword mmixOpcode	zsnni zsnzi zsnpi zsevi
syn keyword mmixOpcode	ldbi ldbui ldwi ldwui
syn keyword mmixOpcode	ldti ldtui ldoi ldoui
syn keyword mmixOpcode	ldsfi ldhti cswapi ldunci
syn keyword mmixOpcode	ldvtsi preldi pregoi goi
syn keyword mmixOpcode	stbi stbui stwi stwui
syn keyword mmixOpcode	stti sttui stoi stoui
syn keyword mmixOpcode	stsfi sthti stcoi stunci
syn keyword mmixOpcode	syncdi presti syncidi pushgoi
syn keyword mmixOpcode	ori orni nori xori
syn keyword mmixOpcode	andi andni nandi nxori
syn keyword mmixOpcode	bdifi wdifi tdifi odifi
syn keyword mmixOpcode	muxi saddi mori mxori
syn keyword mmixOpcode	muli mului divi divui

syn keyword mmixOpcode	flot flotu sflot sflotu
syn keyword mmixOpcode	mul mulu div divu
syn keyword mmixOpcode	add addu sub subu
syn keyword mmixOpcode	2addu 4addu 8addu 16addu
syn keyword mmixOpcode	cmp cmpu neg negu
syn keyword mmixOpcode	sl slu sr sru
syn keyword mmixOpcode	bn bz bp bod
syn keyword mmixOpcode	bnn bnz bnp bev
syn keyword mmixOpcode	pbn pbz pbp pbod
syn keyword mmixOpcode	pbnn pbnz pbnp pbev
syn keyword mmixOpcode	csn csz csp csod
syn keyword mmixOpcode	csnn csnz csnp csev
syn keyword mmixOpcode	zsn zsz zsp zsod
syn keyword mmixOpcode	zsnn zsnz zsnp zsev
syn keyword mmixOpcode	ldb ldbu ldw ldwu
syn keyword mmixOpcode	ldt ldtu ldo ldou
syn keyword mmixOpcode	ldsf ldht cswap ldunc
syn keyword mmixOpcode	ldvts preld prego go
syn keyword mmixOpcode	stb stbu stw stwu
syn keyword mmixOpcode	stt sttu sto stou
syn keyword mmixOpcode	stsf stht stco stunc
syn keyword mmixOpcode	syncd prest syncid pushgo
syn keyword mmixOpcode	or orn nor xor
syn keyword mmixOpcode	and andn nand nxor
syn keyword mmixOpcode	bdif wdif tdif odif
syn keyword mmixOpcode	mux sadd mor mxor

syn keyword mmixOpcode	seth setmh setml setl inch incmh incml incl
syn keyword mmixOpcode	orh ormh orml orl andh andmh andml andnl
syn keyword mmixOpcode	jmp pushj geta put
syn keyword mmixOpcode	pop resume save unsave sync swym get trip
syn keyword mmixOpcode	set lda

" switch back to being case sensitive
syn case match

" general-purpose and special-purpose registers
syn match mmixRegister		"$[0-9]*"
syn match mmixRegister		"r[A-Z]"
syn keyword mmixRegister	rBB rTT rWW rXX rYY rZZ

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_mmix_syntax_inits")
  if version < 508
    let did_mmix_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " The default methods for highlighting.  Can be overridden later
  HiLink mmixAt		Type
  HiLink mmixPseudo	Type
  HiLink mmixRegister	Special
  HiLink mmixSegments	Type

  HiLink mmixLabel	Special
  HiLink mmixComment	Comment
  HiLink mmixOpcode	Keyword

  HiLink hexNumber	Number
  HiLink decNumber	Number
  HiLink octNumber	Number

  HiLink mmixString	String
  HiLink mmixChar	String

  HiLink mmixType	Type
  HiLink mmixIdentifier	Normal
  HiLink mmixSpecialComment Comment

  " My default color overrides:
  " hi mmixSpecialComment ctermfg=red
  "hi mmixLabel ctermfg=lightcyan
  " hi mmixType ctermbg=black ctermfg=brown

  delcommand HiLink
endif

let b:current_syntax = "mmix"

" vim: ts=8
