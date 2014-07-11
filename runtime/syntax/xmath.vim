" Vim syntax file
" Language:	xmath (a simulation tool)
" Maintainer:	Dr. Charles E. Campbell, Jr. <NdrOchipS@PcampbellAfamily.Mbiz>
" Last Change:	Sep 11, 2006
" Version:	6
" URL:	http://mysite.verizon.net/astronaut/vim/index.html#vimlinks_syntax

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" parenthesis sanity checker
syn region xmathZone	matchgroup=Delimiter start="(" matchgroup=Delimiter end=")" transparent contains=ALLBUT,xmathError,xmathBraceError,xmathCurlyError
syn region xmathZone	matchgroup=Delimiter start="{" matchgroup=Delimiter end="}" transparent contains=ALLBUT,xmathError,xmathBraceError,xmathParenError
syn region xmathZone	matchgroup=Delimiter start="\[" matchgroup=Delimiter end="]" transparent contains=ALLBUT,xmathError,xmathCurlyError,xmathParenError
syn match  xmathError	"[)\]}]"
syn match  xmathBraceError	"[)}]"	contained
syn match  xmathCurlyError	"[)\]]"	contained
syn match  xmathParenError	"[\]}]"	contained
syn match  xmathComma	"[,;:]"
syn match  xmathComma	"\.\.\.$"

" A bunch of useful xmath keywords
syn case ignore
syn keyword xmathFuncCmd	function	endfunction	command	endcommand
syn keyword xmathStatement	abort	beep	debug	default	define
syn keyword xmathStatement	execute	exit	pause	return	undefine
syn keyword xmathConditional	if	else	elseif	endif
syn keyword xmathRepeat	while	for	endwhile	endfor
syn keyword xmathCmd	anigraph	deletedatastore	keep	renamedatastore
syn keyword xmathCmd	autocode	deletestd	linkhyper	renamestd
syn keyword xmathCmd	build	deletesuperblock	linksim	renamesuperblock
syn keyword xmathCmd	comment	deletetransition	listusertype	save
syn keyword xmathCmd	copydatastore	deleteusertype	load	sbadisplay
syn keyword xmathCmd	copystd	detailmodel	lock	set
syn keyword xmathCmd	copysuperblock	display	minmax_display	setsbdefault
syn keyword xmathCmd	createblock	documentit	modifyblock	show
syn keyword xmathCmd	createbubble	editcatalog	modifybubble	showlicense
syn keyword xmathCmd	createconnection	erase	modifystd	showsbdefault
syn keyword xmathCmd	creatertf	expandsuperbubble	modifysuperblock	stop
syn keyword xmathCmd	createstd	for	modifytransition	stopcosim
syn keyword xmathCmd	createsuperblock	go	modifyusertype	syntax
syn keyword xmathCmd	createsuperbubble	goto	new	unalias
syn keyword xmathCmd	createtransition	hardcopy	next	unlock
syn keyword xmathCmd	createusertype	help	polargraph	usertype
syn keyword xmathCmd	delete	hyperbuild	print	whatis
syn keyword xmathCmd	deleteblock	if	printmodel	while
syn keyword xmathCmd	deletebubble	ifilter	quit	who
syn keyword xmathCmd	deleteconnection	ipcwc	remove	xgraph

syn keyword xmathFunc	abcd	eye	irea	querystdoptions
syn keyword xmathFunc	abs	eyepattern	is	querysuperblock
syn keyword xmathFunc	acos	feedback	ISID	querysuperblockopt
syn keyword xmathFunc	acosh	fft	ISID	Models	querytransition
syn keyword xmathFunc	adconversion	fftpdm	kronecker	querytransitionopt
syn keyword xmathFunc	afeedback	filter	length	qz
syn keyword xmathFunc	all	find	limit	rampinvar
syn keyword xmathFunc	ambiguity	firparks	lin	random
syn keyword xmathFunc	amdemod	firremez	lin30	randpdm
syn keyword xmathFunc	analytic	firwind	linearfm	randpert
syn keyword xmathFunc	analyze	fmdemod	linfnorm	randsys
syn keyword xmathFunc	any	forwdiff	lintodb	rank
syn keyword xmathFunc	append	fprintf	list	rayleigh
syn keyword xmathFunc	argn	frac	log	rcepstrum
syn keyword xmathFunc	argv	fracred	log10	rcond
syn keyword xmathFunc	arma	freq	logm	rdintegrate
syn keyword xmathFunc	arma2ss	freqcircle	lognormal	read
syn keyword xmathFunc	armax	freqcont	logspace	real
syn keyword xmathFunc	ascii	frequencyhop	lowpass	rectify
syn keyword xmathFunc	asin	fsesti	lpopt	redschur
syn keyword xmathFunc	asinh	fslqgcomp	lqgcomp	reflect
syn keyword xmathFunc	atan	fsregu	lqgltr	regulator
syn keyword xmathFunc	atan2	fwls	ls	residue
syn keyword xmathFunc	atanh	gabor	ls2unc	riccati
syn keyword xmathFunc	attach_ac100	garb	ls2var	riccati_eig
syn keyword xmathFunc	backdiff	gaussian	lsjoin	riccati_schur
syn keyword xmathFunc	balance	gcexp	lu	ricean
syn keyword xmathFunc	balmoore	gcos	lyapunov	rifd
syn keyword xmathFunc	bandpass	gdfileselection	makecontinuous	rlinfo
syn keyword xmathFunc	bandstop	gdmessage	makematrix	rlocus
syn keyword xmathFunc	bj	gdselection	makepoly	rms
syn keyword xmathFunc	blknorm	genconv	margin	rootlocus
syn keyword xmathFunc	bode	get	markoff	roots
syn keyword xmathFunc	bpm	get_info30	matchedpz	round
syn keyword xmathFunc	bpm2inn	get_inn	max	rref
syn keyword xmathFunc	bpmjoin	gfdm	maxlike	rve_get
syn keyword xmathFunc	bpmsplit	gfsk	mean	rve_info
syn keyword xmathFunc	bst	gfskernel	mergeseg	rve_reset
syn keyword xmathFunc	buttconstr	gfunction	min	rve_update
syn keyword xmathFunc	butterworth	ggauss	minimal	samplehold
syn keyword xmathFunc	cancel	giv	mkpert	schur
syn keyword xmathFunc	canform	giv2var	mkphase	sdf
syn keyword xmathFunc	ccepstrum	givjoin	mma	sds
syn keyword xmathFunc	char	gpsk	mmaget	sdtrsp
syn keyword xmathFunc	chebconstr	gpulse	mmaput	sec
syn keyword xmathFunc	chebyshev	gqam	mod	sech
syn keyword xmathFunc	check	gqpsk	modal	siginterp
syn keyword xmathFunc	cholesky	gramp	modalstate	sign
syn keyword xmathFunc	chop	gsawtooth	modcarrier	sim
syn keyword xmathFunc	circonv	gsigmoid	mreduce	sim30
syn keyword xmathFunc	circorr	gsin	mtxplt	simin
syn keyword xmathFunc	clock	gsinc	mu	simin30
syn keyword xmathFunc	clocus	gsqpsk	mulhank	simout
syn keyword xmathFunc	clsys	gsquarewave	multipath	simout30
syn keyword xmathFunc	coherence	gstep	musynfit	simtransform
syn keyword xmathFunc	colorind	GuiDialogCreate	mxstr2xmstr	sin
syn keyword xmathFunc	combinepf	GuiDialogDestroy	mxstring2xmstring	singriccati
syn keyword xmathFunc	commentof	GuiFlush	names	sinh
syn keyword xmathFunc	compare	GuiGetValue	nichols	sinm
syn keyword xmathFunc	complementaryerf	GuiManage	noisefilt	size
syn keyword xmathFunc	complexenvelope	GuiPlot	none	smargin
syn keyword xmathFunc	complexfreqshift	GuiPlotGet	norm	sns2sys
syn keyword xmathFunc	concatseg	GuiSetValue	numden	sort
syn keyword xmathFunc	condition	GuiShellCreate	nyquist	spectrad
syn keyword xmathFunc	conj	GuiShellDeiconify	obscf	spectrum
syn keyword xmathFunc	conmap	GuiShellDestroy	observable	spline
syn keyword xmathFunc	connect	GuiShellIconify	oe	sprintf
syn keyword xmathFunc	conpdm	GuiShellLower	ones	sqrt
syn keyword xmathFunc	constellation	GuiShellRaise	ophank	sqrtm
syn keyword xmathFunc	consys	GuiShellRealize	optimize	sresidualize
syn keyword xmathFunc	controllable	GuiShellUnrealize	optscale	ss2arma
syn keyword xmathFunc	convolve	GuiTimer	orderfilt	sst
syn keyword xmathFunc	correlate	GuiToolCreate	orderstate	ssv
syn keyword xmathFunc	cos	GuiToolDestroy	orth	stable
syn keyword xmathFunc	cosh	GuiToolExist	oscmd	stair
syn keyword xmathFunc	cosm	GuiUnmanage	oscope	starp
syn keyword xmathFunc	cot	GuiWidgetExist	osscale	step
syn keyword xmathFunc	coth	h2norm	padcrop	stepinvar
syn keyword xmathFunc	covariance	h2syn	partialsum	string
syn keyword xmathFunc	csc	hadamard	pdm	stringex
syn keyword xmathFunc	csch	hankelsv	pdmslice	substr
syn keyword xmathFunc	csum	hessenberg	pem	subsys
syn keyword xmathFunc	ctrcf	highpass	perfplots	sum
syn keyword xmathFunc	ctrlplot	hilbert	period	svd
syn keyword xmathFunc	daug	hilberttransform	pfscale	svplot
syn keyword xmathFunc	dbtolin	hinfcontr	phaseshift	sweep
syn keyword xmathFunc	dct	hinfnorm	pinv	symbolmap
syn keyword xmathFunc	decimate	hinfsyn	plot	sys2sns
syn keyword xmathFunc	defFreqRange	histogram	plot30	sysic
syn keyword xmathFunc	defTimeRange	idfreq	pmdemod	Sysid
syn keyword xmathFunc	delay	idimpulse	poisson	system
syn keyword xmathFunc	delsubstr	idsim	poissonimpulse	tan
syn keyword xmathFunc	det	ifft	poleplace	tanh
syn keyword xmathFunc	detrend	imag	poles	taper
syn keyword xmathFunc	dht	impinvar	polezero	tfid
syn keyword xmathFunc	diagonal	impplot	poltrend	toeplitz
syn keyword xmathFunc	differentiate	impulse	polyfit	trace
syn keyword xmathFunc	directsequence	index	polynomial	tril
syn keyword xmathFunc	discretize	indexlist	polyval	trim
syn keyword xmathFunc	divide	initial	polyvalm	trim30
syn keyword xmathFunc	domain	initmodel	prbs	triu
syn keyword xmathFunc	dst	initx0	product	trsp
syn keyword xmathFunc	eig	inn2bpm	psd	truncate
syn keyword xmathFunc	ellipconstr	inn2pe	put_inn	tustin
syn keyword xmathFunc	elliptic	inn2unc	qpopt	uniform
syn keyword xmathFunc	erf	insertseg	qr	val
syn keyword xmathFunc	error	int	quantize	variance
syn keyword xmathFunc	estimator	integrate	queryblock	videolines
syn keyword xmathFunc	etfe	integratedump	queryblockoptions	wcbode
syn keyword xmathFunc	exist	interp	querybubble	wcgain
syn keyword xmathFunc	exp	interpolate	querybubbleoptionswindow
syn keyword xmathFunc	expm	inv	querycatalog	wtbalance
syn keyword xmathFunc	extractchan	invhilbert	queryconnection	zeros
syn keyword xmathFunc	extractseg	iqmix	querystd

syn case match

" Labels (supports xmath's goto)
syn match   xmathLabel	 "^\s*<[a-zA-Z_][a-zA-Z0-9]*>"

" String and Character constants
" Highlight special characters (those which have a backslash) differently
syn match   xmathSpecial	contained "\\\d\d\d\|\\."
syn region  xmathString	start=+"+  skip=+\\\\\|\\"+  end=+"+ contains=xmathSpecial,@Spell
syn match   xmathCharacter	"'[^\\]'"
syn match   xmathSpecialChar	"'\\.'"

syn match   xmathNumber	"-\=\<\d\+L\=\>\|0[xX][0-9a-fA-F]\+\>"

" Comments:
" xmath supports #...  (like Unix shells)
"       and      #{ ... }# comment blocks
syn cluster xmathCommentGroup	contains=xmathString,xmathTodo,@Spell
syn keyword xmathTodo contained	COMBAK	DEBUG	FIXME	Todo	TODO	XXX
syn match   xmathComment	"#.*$"		contains=@xmathCommentGroup
syn region  xmathCommentBlock	start="#{" end="}#"	contains=@xmathCommentGroup

" synchronizing
syn sync match xmathSyncComment	grouphere xmathCommentBlock "#{"
syn sync match xmathSyncComment	groupthere NONE "}#"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_xmath_syntax_inits")
  if version < 508
    let did_xmath_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink xmathBraceError	xmathError
  HiLink xmathCmd	xmathStatement
  HiLink xmathCommentBlock	xmathComment
  HiLink xmathCurlyError	xmathError
  HiLink xmathFuncCmd	xmathStatement
  HiLink xmathParenError	xmathError

  " The default methods for highlighting.  Can be overridden later
  HiLink xmathCharacter	Character
  HiLink xmathComma	Delimiter
  HiLink xmathComment	Comment
  HiLink xmathCommentBlock	Comment
  HiLink xmathConditional	Conditional
  HiLink xmathError	Error
  HiLink xmathFunc	Function
  HiLink xmathLabel	PreProc
  HiLink xmathNumber	Number
  HiLink xmathRepeat	Repeat
  HiLink xmathSpecial	Type
  HiLink xmathSpecialChar	SpecialChar
  HiLink xmathStatement	Statement
  HiLink xmathString	String
  HiLink xmathTodo	Todo

  delcommand HiLink
endif

let b:current_syntax = "xmath"

" vim: ts=17
