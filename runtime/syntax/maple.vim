" Vim syntax file
" Language:	Maple V (based on release 4)
" Maintainer:	Charles E. Campbell <NcampObell@SdrPchip.AorgM-NOSPAM>
" Last Change:	Mar 26, 2019
" Version:	17
" URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_MAPLE
"
" Package Function Selection: {{{1
" Because there are a lot of packages, and because of the potential for namespace
" clashes, this version of <maple.vim> needs the user to select which, if any,
" package functions should be highlighted.  Select your packages and put into your
" <.vimrc> none or more of the lines following let ...=1 lines:
"
"   if exists("mvpkg_all")
"    ...
"   endif
"
" *OR* let mvpkg_all=1

" This syntax file contains all the keywords and top-level packages of Maple 9.5
" but only the contents of packages of Maple V Release 4, and the top-level
" routines of Release 4.  <Jacques Carette - carette@mcmaster.ca>

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Iskeyword Effects: {{{1
if (v:version == 704 && has("patch-7.4.1142")) || v:version > 704
 syn iskeyword $,48-57,_,a-z,@-Z
else
 setl isk=$,48-57,_,a-z,@-Z
endif

" Package Selection: {{{1
" allow user to simply select all packages for highlighting
if exists("mvpkg_all")
  let mv_DEtools    = 1
  let mv_Galois     = 1
  let mv_GaussInt   = 1
  let mv_LREtools   = 1
  let mv_combinat   = 1
  let mv_combstruct = 1
  let mv_difforms   = 1
  let mv_finance    = 1
  let mv_genfunc    = 1
  let mv_geometry   = 1
  let mv_grobner    = 1
  let mv_group      = 1
  let mv_inttrans   = 1
  let mv_liesymm    = 1
  let mv_linalg     = 1
  let mv_logic      = 1
  let mv_networks   = 1
  let mv_numapprox  = 1
  let mv_numtheory  = 1
  let mv_orthopoly  = 1
  let mv_padic      = 1
  let mv_plots      = 1
  let mv_plottools  = 1
  let mv_powseries  = 1
  let mv_process    = 1
  let mv_simplex    = 1
  let mv_stats      = 1
  let mv_student    = 1
  let mv_sumtools   = 1
  let mv_tensor     = 1
  let mv_totorder   = 1
endif

" Parenthesis/curly/brace sanity checker: {{{1
syn case match

" parenthesis/curly/brace sanity checker
syn region mvZone	matchgroup=Delimiter start="(" matchgroup=Delimiter end=")" transparent contains=ALLBUT,mvError,mvBraceError,mvCurlyError
syn region mvZone	matchgroup=Delimiter start="{" matchgroup=Delimiter end="}" transparent contains=ALLBUT,mvError,mvBraceError,mvParenError
syn region mvZone	matchgroup=Delimiter start="\[" matchgroup=Delimiter end="]" transparent contains=ALLBUT,mvError,mvCurlyError,mvParenError
syn match  mvError		"[)\]}]"
syn match  mvBraceError	"[)}]"	contained
syn match  mvCurlyError	"[)\]]"	contained
syn match  mvParenError	"[\]}]"	contained
syn match  mvComma		"[,;:]"
syn match  mvSemiError	"[;:]"	contained
syn match  mvDcolon		"::"

" Maple Packages, updated for Maple 9.5
syn keyword mvPackage	algcurves	ArrayTools	Cache	codegen
syn keyword mvPackage	CodeGeneration	CodeTools	combinat	combstruct
syn keyword mvPackage	ContextMenu	CurveFitting	DEtools	diffalg
syn keyword mvPackage	difforms	DiscreteTransforms	Domains	ExternalCalling
syn keyword mvPackage	FileTools	finance	GaussInt	genfunc
syn keyword mvPackage	geom3d	geometry	gfun	Groebner
syn keyword mvPackage	group	hashmset	IntegerRelations	inttrans
syn keyword mvPackage	LargeExpressions	LibraryTools	liesymm	linalg
syn keyword mvPackage	LinearAlgebra	LinearFunctionalSystems	LinearOperators
syn keyword mvPackage	ListTools	Logic	LREtools	Maplets
syn keyword mvPackage	MathematicalFunctions	MathML	Matlab
syn keyword mvPackage	MatrixPolynomialAlgebra	MmaTranslator	networks
syn keyword mvPackage	numapprox	numtheory	Optimization	OreTools
syn keyword mvPackage	Ore_algebra	OrthogonalSeries	orthopoly	padic
syn keyword mvPackage	PDEtools	plots	plottools	PolynomialIdeals
syn keyword mvPackage	PolynomialTools	powseries	process	QDifferenceEquations
syn keyword mvPackage	RandomTools	RationalNormalForms	RealDomain	RootFinding
syn keyword mvPackage	ScientificConstants	ScientificErrorAnalysis	simplex
syn keyword mvPackage	Slode	SNAP	Sockets	SoftwareMetrics
syn keyword mvPackage	SolveTools	Spread	stats	StringTools
syn keyword mvPackage	Student	student	sumtools	SumTools
syn keyword mvPackage	tensor	TypeTools	Units	VariationalCalculus
syn keyword mvPackage	VectorCalculus	Worksheet	XMLTools

" Language Support: {{{1
syn keyword mvTodo	contained	COMBAK	FIXME	TODO	XXX
if exists("g:mapleversion") && g:mapleversion < 9
 syn region  mvString	start=+`+ skip=+``+ end=+`+	keepend	contains=mvTodo,@Spell
 syn region  mvString	start=+"+ skip=+""+ end=+"+	keepend	contains=@Spell
 syn region  mvDelayEval	start=+'+ end=+'+	keepend contains=ALLBUT,mvError,mvBraceError,mvCurlyError,mvParenError,mvSemiError
 syn match   mvVarAssign	"[a-zA-Z_][a-zA-Z_0-9]*[ \t]*:=" contains=mvAssign
 syn match   mvAssign	":="	contained
else
 syn region  mvName		start=+`+ skip=+``+ end=+`+	keepend	contains=mvTodo
 syn region  mvString	start=+"+ skip=+""+ end=+"+	keepend	contains=@Spell
 syn region  mvDelayEval	start=+'+ end=+'+	keepend contains=ALLBUT,mvError,mvBraceError,mvCurlyError,mvParenError
 syn match   mvDelim		"[;:]"	display
 syn match   mvAssign	":="
endif

" Lower-Priority Operators: {{{1
syn match mvOper	"\."

" Number handling: {{{1
syn match mvNumber	"\<\d\+"		" integer
 syn match mvNumber	"[-+]\=\.\d\+"		" . integer
syn match mvNumber	"\<\d\+\.\d\+"		" integer . integer
syn match mvNumber	"\<\d\+\."		" integer .
syn match mvNumber	"\<\d\+\.\."	contains=mvRange	" integer ..

syn match mvNumber	"\<\d\+e[-+]\=\d\+"		" integer e [-+] integer
syn match mvNumber	"[-+]\=\.\d\+e[-+]\=\d\+"	" . integer e [-+] integer
syn match mvNumber	"\<\d\+\.\d*e[-+]\=\d\+"	" integer . [integer] e [-+] integer

syn match mvNumber	"[-+]\d\+"		" integer
syn match mvNumber	"[-+]\d\+\.\d\+"		" integer . integer
syn match mvNumber	"[-+]\d\+\."		" integer .
syn match mvNumber	"[-+]\d\+\.\."	contains=mvRange	" integer ..

syn match mvNumber	"[-+]\d\+e[-+]\=\d\+"	" integer e [-+] integer
syn match mvNumber	"[-+]\d\+\.\d*e[-+]\=\d\+"	" integer . [integer] e [-+] integer

syn match mvRange	"\.\."

" Operators: {{{1
syn keyword mvOper	and not or xor implies union intersect subset minus mod
syn match   mvOper	"<>\|[<>]=\|[<>]\|="
syn match   mvOper	"&+\|&-\|&\*\|&\/\|&"
syn match   mvError	"\.\.\."

" MapleV Statements: ? statement {{{1

" MapleV Statements: ? statement
" Split into booleans, conditionals, operators, repeat-logic, etc
syn keyword mvBool	true	false	FAIL
syn keyword mvCond	elif	else	fi	if	then
syn match   mvCond	"end\s\+if"

syn keyword mvRepeat	by	for	in	to
syn keyword mvRepeat	do	from	od	while
syn match   mvRepeat	"end\s\+do"

syn keyword mvSpecial	NULL
syn match   mvSpecial	"\[\]\|{}"

if exists("g:mapleversion") && g:mapleversion < 9
 syn keyword mvStatement	Order	fail	options	read	save
 syn keyword mvStatement	break	local	point	remember	stop
 syn keyword mvStatement	done	mod	proc	restart	with
 syn keyword mvStatement	end	mods	quit	return
 syn keyword mvStatement	error	next
else
 syn keyword mvStatement	option	options	read	save
 syn keyword mvStatement	break	local	remember	stop
 syn keyword mvStatement	done	mod	proc	restart
 syn keyword mvStatement	end	mods	quit	return
 syn keyword mvStatement	error	next	try	catch
 syn keyword mvStatement	finally	assuming	global	export
 syn keyword mvStatement	module	description	use
endif

" Builtin Constants: ? constants {{{1
syn keyword mvConstant	Catalan	I	gamma	infinity
syn keyword mvConstant	Pi

" Comments:  DEBUG, if in a comment, is specially highlighted. {{{1
syn keyword mvDebug	contained	DEBUG
syn cluster mvCommentGroup	contains=mvTodo,mvDebug,@Spell
syn match mvComment "#.*$"	contains=@mvCommentGroup

" Basic Library Functions: ? index[function]
syn keyword mvLibrary $	@	@@	ERROR
syn keyword mvLibrary AFactor	KelvinHer	arctan	factor	log	rhs
syn keyword mvLibrary AFactors	KelvinKei	arctanh	factors	log10	root
syn keyword mvLibrary AiryAi	KelvinKer	argument	fclose	lprint	roots
syn keyword mvLibrary AiryBi	LambertW	array	feof	map	round
syn keyword mvLibrary AngerJ	Lcm	assign	fflush	map2	rsolve
syn keyword mvLibrary Berlekamp	LegendreE	assigned	filepos	match	savelib
syn keyword mvLibrary BesselI	LegendreEc	asspar	fixdiv	matrix	scanf
syn keyword mvLibrary BesselJ	LegendreEc1	assume	float	max	searchtext
syn keyword mvLibrary BesselK	LegendreF	asubs	floor	maximize	sec
syn keyword mvLibrary BesselY	LegendreKc	asympt	fnormal	maxnorm	sech
syn keyword mvLibrary Beta	LegendreKc1	attribute	fopen	maxorder	select
syn keyword mvLibrary C	LegendrePi	bernstein	forget	member	seq
syn keyword mvLibrary Chi	LegendrePic	branches	fortran	min	series
syn keyword mvLibrary Ci	LegendrePic1	bspline	fprintf	minimize	setattribute
syn keyword mvLibrary CompSeq	Li	cat	frac	minpoly	shake
syn keyword mvLibrary Content	Linsolve	ceil	freeze	modp	showprofile
syn keyword mvLibrary D	MOLS	chrem	fremove	modp1	showtime
syn keyword mvLibrary DESol	Maple_floats	close	frontend	modp2	sign
syn keyword mvLibrary Det	MeijerG	close	fscanf	modpol	signum
syn keyword mvLibrary Diff	Norm	coeff	fsolve	mods	simplify
syn keyword mvLibrary Dirac	Normal	coeffs	galois	msolve	sin
syn keyword mvLibrary DistDeg	Nullspace	coeftayl	gc	mtaylor	singular
syn keyword mvLibrary Divide	Power	collect	gcd	mul	sinh
syn keyword mvLibrary Ei	Powmod	combine	gcdex	nextprime	sinterp
syn keyword mvLibrary Eigenvals	Prem	commutat	genpoly	nops	solve
syn keyword mvLibrary EllipticCE	Primfield	comparray	harmonic	norm	sort
syn keyword mvLibrary EllipticCK	Primitive	compoly	has	normal	sparse
syn keyword mvLibrary EllipticCPi	Primpart	conjugate	hasfun	numboccur	spline
syn keyword mvLibrary EllipticE	ProbSplit	content	hasoption	numer	split
syn keyword mvLibrary EllipticF	Product	convergs	hastype	op	splits
syn keyword mvLibrary EllipticK	Psi	convert	heap	open	sprem
syn keyword mvLibrary EllipticModulus	Quo	coords	history	optimize	sprintf
syn keyword mvLibrary EllipticNome	RESol	copy	hypergeom	order	sqrfree
syn keyword mvLibrary EllipticPi	Randpoly	cos	iFFT	parse	sqrt
syn keyword mvLibrary Eval	Randprime	cosh	icontent	pclose	sscanf
syn keyword mvLibrary Expand	Ratrecon	cost	identity	pclose	ssystem
syn keyword mvLibrary FFT	Re	cot	igcd	pdesolve	stack
syn keyword mvLibrary Factor	Rem	coth	igcdex	piecewise	sturm
syn keyword mvLibrary Factors	Resultant	csc	ilcm	plot	sturmseq
syn keyword mvLibrary FresnelC	RootOf	csch	ilog	plot3d	subs
syn keyword mvLibrary FresnelS	Roots	csgn	ilog10	plotsetup	subsop
syn keyword mvLibrary Fresnelf	SPrem	dawson	implicitdiff	pochhammer	substring
syn keyword mvLibrary Fresnelg	Searchtext	define	indets	pointto	sum
syn keyword mvLibrary Frobenius	Shi	degree	index	poisson	surd
syn keyword mvLibrary GAMMA	Si	denom	indexed	polar	symmdiff
syn keyword mvLibrary GaussAGM	Smith	depends	indices	polylog	symmetric
syn keyword mvLibrary Gaussejord	Sqrfree	diagonal	inifcn	polynom	system
syn keyword mvLibrary Gausselim	Ssi	diff	ininame	powmod	table
syn keyword mvLibrary Gcd	StruveH	dilog	initialize	prem	tan
syn keyword mvLibrary Gcdex	StruveL	dinterp	insert	prevprime	tanh
syn keyword mvLibrary HankelH1	Sum	disassemble	int	primpart	testeq
syn keyword mvLibrary HankelH2	Svd	discont	interface	print	testfloat
syn keyword mvLibrary Heaviside	TEXT	discrim	interp	printf	thaw
syn keyword mvLibrary Hermite	Trace	dismantle	invfunc	procbody	thiele
syn keyword mvLibrary Im	WeberE	divide	invztrans	procmake	time
syn keyword mvLibrary Indep	WeierstrassP	dsolve	iostatus	product	translate
syn keyword mvLibrary Interp	WeierstrassPPrime	eliminate	iperfpow	proot	traperror
syn keyword mvLibrary Inverse	WeierstrassSigma	ellipsoid	iquo	property	trigsubs
syn keyword mvLibrary Irreduc	WeierstrassZeta	entries	iratrecon	protect	trunc
syn keyword mvLibrary Issimilar	Zeta	eqn	irem	psqrt	type
syn keyword mvLibrary JacobiAM	abs	erf	iroot	quo	typematch
syn keyword mvLibrary JacobiCD	add	erfc	irreduc	radnormal	unames
syn keyword mvLibrary JacobiCN	addcoords	eulermac	iscont	radsimp	unapply
syn keyword mvLibrary JacobiCS	addressof	eval	isdifferentiable	rand	unassign
syn keyword mvLibrary JacobiDC	algebraic	evala	isolate	randomize	unload
syn keyword mvLibrary JacobiDN	algsubs	evalapply	ispoly	randpoly	unprotect
syn keyword mvLibrary JacobiDS	alias	evalb	isqrfree	range	updatesR4
syn keyword mvLibrary JacobiNC	allvalues	evalc	isqrt	rationalize	userinfo
syn keyword mvLibrary JacobiND	anames	evalf	issqr	ratrecon	value
syn keyword mvLibrary JacobiNS	antisymm	evalfint	latex	readbytes	vector
syn keyword mvLibrary JacobiSC	applyop	evalgf	lattice	readdata	verify
syn keyword mvLibrary JacobiSD	arccos	evalhf	lcm	readlib	whattype
syn keyword mvLibrary JacobiSN	arccosh	evalm	lcoeff	readline	with
syn keyword mvLibrary JacobiTheta1	arccot	evaln	leadterm	readstat	writebytes
syn keyword mvLibrary JacobiTheta2	arccoth	evalr	length	realroot	writedata
syn keyword mvLibrary JacobiTheta3	arccsc	exp	lexorder	recipoly	writeline
syn keyword mvLibrary JacobiTheta4	arccsch	expand	lhs	rem	writestat
syn keyword mvLibrary JacobiZeta	arcsec	expandoff	limit	remove	writeto
syn keyword mvLibrary KelvinBei	arcsech	expandon	ln	residue	zip
syn keyword mvLibrary KelvinBer	arcsin	extract	lnGAMMA	resultant	ztrans
syn keyword mvLibrary KelvinHei	arcsinh


" ==  PACKAGES  ======================================================= {{{1
" Note: highlighting of package functions is now user-selectable by package.

" Package: DEtools     differential equations tools {{{2
if exists("mv_DEtools")
  syn keyword mvPkg_DEtools	DEnormal	Dchangevar	autonomous	dfieldplot	reduceOrder	untranslate
  syn keyword mvPkg_DEtools	DEplot	PDEchangecoords	convertAlg	indicialeq	regularsp	varparam
  syn keyword mvPkg_DEtools	DEplot3d	PDEplot	convertsys	phaseportrait	translate
endif

" Package: Domains: create domains of computation {{{2
if exists("mv_Domains")
endif

" Package: GF: Galois Fields {{{2
if exists("mv_GF")
  syn keyword mvPkg_Galois	galois
endif

" Package: GaussInt: Gaussian Integers {{{2
if exists("mv_GaussInt")
  syn keyword mvPkg_GaussInt	GIbasis	GIfactor	GIissqr	GInorm	GIquadres	GIsmith
  syn keyword mvPkg_GaussInt	GIchrem	GIfactors	GIlcm	GInormal	GIquo	GIsqrfree
  syn keyword mvPkg_GaussInt	GIdivisor	GIgcd	GImcmbine	GIorder	GIrem	GIsqrt
  syn keyword mvPkg_GaussInt	GIfacpoly	GIgcdex	GInearest	GIphi	GIroots	GIunitnormal
  syn keyword mvPkg_GaussInt	GIfacset	GIhermite	GInodiv	GIprime	GIsieve
endif

" Package: LREtools: manipulate linear recurrence relations {{{2
if exists("mv_LREtools")
  syn keyword mvPkg_LREtools	REcontent	REprimpart	REtodelta	delta	hypergeomsols	ratpolysols
  syn keyword mvPkg_LREtools	REcreate	REreduceorder	REtoproc	dispersion	polysols	shift
  syn keyword mvPkg_LREtools	REplot	REtoDE	constcoeffsol
endif

" Package: combinat: combinatorial functions {{{2
if exists("mv_combinat")
  syn keyword mvPkg_combinat	Chi	composition	graycode	numbcomb	permute	randperm
  syn keyword mvPkg_combinat	bell	conjpart	inttovec	numbcomp	powerset	stirling1
  syn keyword mvPkg_combinat	binomial	decodepart	lastpart	numbpart	prevpart	stirling2
  syn keyword mvPkg_combinat	cartprod	encodepart	multinomial	numbperm	randcomb	subsets
  syn keyword mvPkg_combinat	character	fibonacci	nextpart	partition	randpart	vectoint
  syn keyword mvPkg_combinat	choose	firstpart
endif

" Package: combstruct: combinatorial structures {{{2
if exists("mv_combstruct")
  syn keyword mvPkg_combstruct	allstructs	draw	iterstructs	options	specification	structures
  syn keyword mvPkg_combstruct	count	finished	nextstruct
endif

" Package: difforms: differential forms {{{2
if exists("mv_difforms")
  syn keyword mvPkg_difforms	const	defform	formpart	parity	scalarpart	wdegree
  syn keyword mvPkg_difforms	d	form	mixpar	scalar	simpform	wedge
endif

" Package: finance: financial mathematics {{{2
if exists("mv_finance")
  syn keyword mvPkg_finance	amortization	cashflows	futurevalue	growingperpetuity	mv_finance	presentvalue
  syn keyword mvPkg_finance	annuity	effectiverate	growingannuity	levelcoupon	perpetuity	yieldtomaturity
  syn keyword mvPkg_finance	blackscholes
endif

" Package: genfunc: rational generating functions {{{2
if exists("mv_genfunc")
  syn keyword mvPkg_genfunc	rgf_charseq	rgf_expand	rgf_hybrid	rgf_pfrac	rgf_sequence	rgf_term
  syn keyword mvPkg_genfunc	rgf_encode	rgf_findrecur	rgf_norm	rgf_relate	rgf_simp	termscale
endif

" Package: geometry: Euclidean geometry {{{2
if exists("mv_geometry")
  syn keyword mvPkg_geometry	circle	dsegment	hyperbola	parabola	segment	triangle
  syn keyword mvPkg_geometry	conic	ellipse	line	point	square
endif

" Package: grobner: Grobner bases {{{2
if exists("mv_grobner")
  syn keyword mvPkg_grobner	finduni	gbasis	leadmon	normalf	solvable	spoly
  syn keyword mvPkg_grobner	finite	gsolve
endif

" Package: group: permutation and finitely-presented groups {{{2
if exists("mv_group")
  syn keyword mvPkg_group	DerivedS	areconjugate	cosets	grouporder	issubgroup	permrep
  syn keyword mvPkg_group	LCS	center	cosrep	inter	mulperms	pres
  syn keyword mvPkg_group	NormalClosure	centralizer	derived	invperm	normalizer	subgrel
  syn keyword mvPkg_group	RandElement	convert	grelgroup	isabelian	orbit	type
  syn keyword mvPkg_group	Sylow	core	groupmember	isnormal	permgroup
endif

" Package: inttrans: integral transforms {{{2
if exists("mv_inttrans")
  syn keyword mvPkg_inttrans	addtable	fouriercos	hankel	invfourier	invlaplace	mellin
  syn keyword mvPkg_inttrans	fourier	fouriersin	hilbert	invhilbert	laplace
endif

" Package: liesymm: Lie symmetries {{{2
if exists("mv_liesymm")
  syn keyword mvPkg_liesymm	&^	TD	depvars	getform	mixpar	vfix
  syn keyword mvPkg_liesymm	&mod	annul	determine	hasclosure	prolong	wcollect
  syn keyword mvPkg_liesymm	Eta	autosimp	dvalue	hook	reduce	wdegree
  syn keyword mvPkg_liesymm	Lie	close	extvars	indepvars	setup	wedgeset
  syn keyword mvPkg_liesymm	Lrank	d	getcoeff	makeforms	translate	wsubs
endif

" Package: linalg: Linear algebra {{{2
if exists("mv_linalg")
  syn keyword mvPkg_linalg	GramSchmidt	coldim	equal	indexfunc	mulcol	singval
  syn keyword mvPkg_linalg	JordanBlock	colspace	exponential	innerprod	multiply	smith
  syn keyword mvPkg_linalg	LUdecomp	colspan	extend	intbasis	norm	stack
  syn keyword mvPkg_linalg	QRdecomp	companion	ffgausselim	inverse	normalize	submatrix
  syn keyword mvPkg_linalg	addcol	cond	fibonacci	ismith	orthog	subvector
  syn keyword mvPkg_linalg	addrow	copyinto	forwardsub	issimilar	permanent	sumbasis
  syn keyword mvPkg_linalg	adjoint	crossprod	frobenius	iszero	pivot	swapcol
  syn keyword mvPkg_linalg	angle	curl	gausselim	jacobian	potential	swaprow
  syn keyword mvPkg_linalg	augment	definite	gaussjord	jordan	randmatrix	sylvester
  syn keyword mvPkg_linalg	backsub	delcols	geneqns	kernel	randvector	toeplitz
  syn keyword mvPkg_linalg	band	delrows	genmatrix	laplacian	rank	trace
  syn keyword mvPkg_linalg	basis	det	grad	leastsqrs	references	transpose
  syn keyword mvPkg_linalg	bezout	diag	hadamard	linsolve	row	vandermonde
  syn keyword mvPkg_linalg	blockmatrix	diverge	hermite	matadd	rowdim	vecpotent
  syn keyword mvPkg_linalg	charmat	dotprod	hessian	matrix	rowspace	vectdim
  syn keyword mvPkg_linalg	charpoly	eigenval	hilbert	minor	rowspan	vector
  syn keyword mvPkg_linalg	cholesky	eigenvect	htranspose	minpoly	scalarmul	wronskian
  syn keyword mvPkg_linalg	col	entermatrix	ihermite
endif

" Package: logic: Boolean logic {{{2
if exists("mv_logic")
  syn keyword mvPkg_logic	MOD2	bsimp	distrib	environ	randbool	tautology
  syn keyword mvPkg_logic	bequal	canon	dual	frominert	satisfy	toinert
endif

" Package: networks: graph networks {{{2
if exists("mv_networks")
  syn keyword mvPkg_networks	acycpoly	connect	dinic	graph	mincut	show
  syn keyword mvPkg_networks	addedge	connectivity	djspantree	graphical	mindegree	shrink
  syn keyword mvPkg_networks	addvertex	contract	dodecahedron	gsimp	neighbors	span
  syn keyword mvPkg_networks	adjacency	countcuts	draw	gunion	new	spanpoly
  syn keyword mvPkg_networks	allpairs	counttrees	duplicate	head	octahedron	spantree
  syn keyword mvPkg_networks	ancestor	cube	edges	icosahedron	outdegree	tail
  syn keyword mvPkg_networks	arrivals	cycle	ends	incidence	path	tetrahedron
  syn keyword mvPkg_networks	bicomponents	cyclebase	eweight	incident	petersen	tuttepoly
  syn keyword mvPkg_networks	charpoly	daughter	flow	indegree	random	vdegree
  syn keyword mvPkg_networks	chrompoly	degreeseq	flowpoly	induce	rank	vertices
  syn keyword mvPkg_networks	complement	delete	fundcyc	isplanar	rankpoly	void
  syn keyword mvPkg_networks	complete	departures	getlabel	maxdegree	shortpathtree	vweight
  syn keyword mvPkg_networks	components	diameter	girth
endif

" Package: numapprox: numerical approximation {{{2
if exists("mv_numapprox")
  syn keyword mvPkg_numapprox	chebdeg	chebsort	fnorm	laurent	minimax	remez
  syn keyword mvPkg_numapprox	chebmult	chebyshev	hornerform	laurent	pade	taylor
  syn keyword mvPkg_numapprox	chebpade	confracform	infnorm	minimax
endif

" Package: numtheory: number theory {{{2
if exists("mv_numtheory")
  syn keyword mvPkg_numtheory	B	cyclotomic	invcfrac	mcombine	nthconver	primroot
  syn keyword mvPkg_numtheory	F	divisors	invphi	mersenne	nthdenom	quadres
  syn keyword mvPkg_numtheory	GIgcd	euler	isolve	minkowski	nthnumer	rootsunity
  syn keyword mvPkg_numtheory	J	factorEQ	isprime	mipolys	nthpow	safeprime
  syn keyword mvPkg_numtheory	L	factorset	issqrfree	mlog	order	sigma
  syn keyword mvPkg_numtheory	M	fermat	ithprime	mobius	pdexpand	sq2factor
  syn keyword mvPkg_numtheory	bernoulli	ifactor	jacobi	mroot	phi	sum2sqr
  syn keyword mvPkg_numtheory	bigomega	ifactors	kronecker	msqrt	pprimroot	tau
  syn keyword mvPkg_numtheory	cfrac	imagunit	lambda	nearestp	prevprime	thue
  syn keyword mvPkg_numtheory	cfracpol	index	legendre	nextprime
endif

" Package: orthopoly: orthogonal polynomials {{{2
if exists("mv_orthopoly")
  syn keyword mvPkg_orthopoly	G	H	L	P	T	U
endif

" Package: padic: p-adic numbers {{{2
if exists("mv_padic")
  syn keyword mvPkg_padic	evalp	function	orderp	ratvaluep	rootp	valuep
  syn keyword mvPkg_padic	expansion	lcoeffp	ordp
endif

" Package: plots: graphics package {{{2
if exists("mv_plots")
  syn keyword mvPkg_plots	animate	coordplot3d	gradplot3d	listplot3d	polarplot	setoptions3d
  syn keyword mvPkg_plots	animate3d	cylinderplot	implicitplot	loglogplot	polygonplot	spacecurve
  syn keyword mvPkg_plots	changecoords	densityplot	implicitplot3d	logplot	polygonplot3d	sparsematrixplot
  syn keyword mvPkg_plots	complexplot	display	inequal	matrixplot	polyhedraplot	sphereplot
  syn keyword mvPkg_plots	complexplot3d	display3d	listcontplot	odeplot	replot	surfdata
  syn keyword mvPkg_plots	conformal	fieldplot	listcontplot3d	pareto	rootlocus	textplot
  syn keyword mvPkg_plots	contourplot	fieldplot3d	listdensityplot	pointplot	semilogplot	textplot3d
  syn keyword mvPkg_plots	contourplot3d	gradplot	listplot	pointplot3d	setoptions	tubeplot
  syn keyword mvPkg_plots	coordplot
endif

" Package: plottools: basic graphical objects {{{2
if exists("mv_plottools")
  syn keyword mvPkg_plottools	arc	curve	dodecahedron	hyperbola	pieslice	semitorus
  syn keyword mvPkg_plottools	arrow	cutin	ellipse	icosahedron	point	sphere
  syn keyword mvPkg_plottools	circle	cutout	ellipticArc	line	polygon	tetrahedron
  syn keyword mvPkg_plottools	cone	cylinder	hemisphere	octahedron	rectangle	torus
  syn keyword mvPkg_plottools	cuboid	disk	hexahedron
endif

" Package: powseries: formal power series {{{2
if exists("mv_powseries")
  syn keyword mvPkg_powseries	compose	multiply	powcreate	powlog	powsolve	reversion
  syn keyword mvPkg_powseries	evalpow	negative	powdiff	powpoly	powsqrt	subtract
  syn keyword mvPkg_powseries	inverse	powadd	powexp	powseries	quotient	tpsform
  syn keyword mvPkg_powseries	multconst	powcos	powint	powsin
endif

" Package: process: (Unix)-multi-processing {{{2
if exists("mv_process")
  syn keyword mvPkg_process	block	fork	pclose	pipe	popen	wait
  syn keyword mvPkg_process	exec	kill
endif

" Package: simplex: linear optimization {{{2
if exists("mv_simplex")
  syn keyword mvPkg_simplex	NONNEGATIVE	cterm	dual	maximize	pivoteqn	setup
  syn keyword mvPkg_simplex	basis	define_zero	equality	minimize	pivotvar	standardize
  syn keyword mvPkg_simplex	convexhull	display	feasible	pivot	ratio
endif

" Package: stats: statistics {{{2
if exists("mv_stats")
  syn keyword mvPkg_stats	anova	describe	fit	random	statevalf	statplots
endif

" Package: student: student calculus {{{2
if exists("mv_student")
  syn keyword mvPkg_student	D	Product	distance	isolate	middlesum	rightsum
  syn keyword mvPkg_student	Diff	Sum	equate	leftbox	midpoint	showtangent
  syn keyword mvPkg_student	Doubleint	Tripleint	extrema	leftsum	minimize	simpson
  syn keyword mvPkg_student	Int	changevar	integrand	makeproc	minimize	slope
  syn keyword mvPkg_student	Limit	combine	intercept	maximize	powsubs	trapezoid
  syn keyword mvPkg_student	Lineint	completesquare	intparts	middlebox	rightbox	value
  syn keyword mvPkg_student	Point
endif

" Package: sumtools: indefinite and definite sums {{{2
if exists("mv_sumtools")
  syn keyword mvPkg_sumtools	Hypersum	extended_gosper	hyperrecursion	hyperterm	sumrecursion	sumtohyper
  syn keyword mvPkg_sumtools	Sumtohyper	gosper	hypersum	simpcomb
endif

" Package: tensor: tensor computations and General Relativity {{{2
if exists("mv_tensor")
  syn keyword mvPkg_tensor	Christoffel1	Riemann	connexF	display_allGR	get_compts	partial_diff
  syn keyword mvPkg_tensor	Christoffel2	RiemannF	contract	dual	get_rank	permute_indices
  syn keyword mvPkg_tensor	Einstein	Weyl	convertNP	entermetric	invars	petrov
  syn keyword mvPkg_tensor	Jacobian	act	cov_diff	exterior_diff	invert	prod
  syn keyword mvPkg_tensor	Killing_eqns	antisymmetrize	create	exterior_prod	lin_com	raise
  syn keyword mvPkg_tensor	Levi_Civita	change_basis	d1metric	frame	lower	symmetrize
  syn keyword mvPkg_tensor	Lie_diff	commutator	d2metric	geodesic_eqns	npcurve	tensorsGR
  syn keyword mvPkg_tensor	Ricci	compare	directional_diff	get_char	npspin	transform
  syn keyword mvPkg_tensor	Ricciscalar	conj	displayGR
endif

" Package: totorder: total orders on names {{{2
if exists("mv_totorder")
  syn keyword mvPkg_totorder	forget	init	ordering	tassume	tis
endif
" =====================================================================

" Highlighting: Define the default highlighting. {{{1
" Only when an item doesn't have highlighting yet
if !exists("skip_maplev_syntax_inits")

  " Maple->Maple Links {{{2
  hi def link mvBraceError	mvError
  hi def link mvCurlyError	mvError
  hi def link mvDebug		mvTodo
  hi def link mvParenError	mvError
  hi def link mvPkg_DEtools	mvPkgFunc
  hi def link mvPkg_Galois	mvPkgFunc
  hi def link mvPkg_GaussInt	mvPkgFunc
  hi def link mvPkg_LREtools	mvPkgFunc
  hi def link mvPkg_combinat	mvPkgFunc
  hi def link mvPkg_combstruct	mvPkgFunc
  hi def link mvPkg_difforms	mvPkgFunc
  hi def link mvPkg_finance	mvPkgFunc
  hi def link mvPkg_genfunc	mvPkgFunc
  hi def link mvPkg_geometry	mvPkgFunc
  hi def link mvPkg_grobner	mvPkgFunc
  hi def link mvPkg_group	mvPkgFunc
  hi def link mvPkg_inttrans	mvPkgFunc
  hi def link mvPkg_liesymm	mvPkgFunc
  hi def link mvPkg_linalg	mvPkgFunc
  hi def link mvPkg_logic	mvPkgFunc
  hi def link mvPkg_networks	mvPkgFunc
  hi def link mvPkg_numapprox	mvPkgFunc
  hi def link mvPkg_numtheory	mvPkgFunc
  hi def link mvPkg_orthopoly	mvPkgFunc
  hi def link mvPkg_padic	mvPkgFunc
  hi def link mvPkg_plots	mvPkgFunc
  hi def link mvPkg_plottools	mvPkgFunc
  hi def link mvPkg_powseries	mvPkgFunc
  hi def link mvPkg_process	mvPkgFunc
  hi def link mvPkg_simplex	mvPkgFunc
  hi def link mvPkg_stats	mvPkgFunc
  hi def link mvPkg_student	mvPkgFunc
  hi def link mvPkg_sumtools	mvPkgFunc
  hi def link mvPkg_tensor	mvPkgFunc
  hi def link mvPkg_totorder	mvPkgFunc
  hi def link mvRange		mvOper
  hi def link mvSemiError	mvError
  hi def link mvDelim		Delimiter

  " Maple->Standard Links {{{2
  hi def link mvAssign		Delimiter
  hi def link mvBool		Boolean
  hi def link mvComma		Delimiter
  hi def link mvComment		Comment
  hi def link mvCond		Conditional
  hi def link mvConstant		Number
  hi def link mvDelayEval	Label
  hi def link mvDcolon		Delimiter
  hi def link mvError		Error
  hi def link mvLibrary		Statement
  hi def link mvNumber		Number
  hi def link mvOper		Operator
  hi def link mvAssign		Delimiter
  hi def link mvPackage		Type
  hi def link mvPkgFunc		Function
  hi def link mvPktOption	Special
  hi def link mvRepeat		Repeat
  hi def link mvSpecial		Special
  hi def link mvStatement	Statement
  hi def link mvName		String
  hi def link mvString		String
  hi def link mvTodo		Todo

endif

" Current Syntax: {{{1
let b:current_syntax = "maple"
" vim: ts=20 fdm=marker
