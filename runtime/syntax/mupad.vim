" Vim syntax file
" Language:    MuPAD source
" Maintainer:  Dave Silvia <dsilvia@mchsi.com>
" Filenames:   *.mu
" Date:        6/30/2004


" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Set default highlighting to Win2k
if !exists("mupad_cmdextversion")
  let mupad_cmdextversion = 2
endif

syn case match

syn match mupadComment	"//\p*$"
syn region mupadComment	start="/\*"	end="\*/"

syn region mupadString	start="\""	skip=/\\"/	end="\""

syn match mupadOperator		"(\|)\|:=\|::\|:\|;"
" boolean
syn keyword mupadOperator	and	or	not	xor
syn match mupadOperator		"==>\|\<=\>"

" Informational
syn keyword mupadSpecial		FILEPATH	NOTEBOOKFILE	NOTEBOOKPATH
" Set-able, e.g., DIGITS:=10
syn keyword mupadSpecial		DIGITS		HISTORY		LEVEL
syn keyword mupadSpecial		MAXLEVEL	MAXDEPTH	ORDER
syn keyword mupadSpecial		TEXTWIDTH
" Set-able, e.g., PRETTYPRINT:=TRUE
syn keyword mupadSpecial		PRETTYPRINT
" Set-able, e.g., LIBPATH:="C:\\MuPAD Pro\\mylibdir" or LIBPATH:="/usr/MuPAD Pro/mylibdir"
syn keyword mupadSpecial		LIBPATH		PACKAGEPATH
syn keyword mupadSpecial		READPATH	TESTPATH	WRITEPATH
" Symbols and Constants
syn keyword mupadDefine		FAIL		NIL
syn keyword mupadDefine		TRUE		FALSE		UNKNOWN
syn keyword mupadDefine		complexInfinity		infinity
syn keyword mupadDefine		C_	CATALAN	E	EULER	I	PI	Q_	R_
syn keyword mupadDefine		RD_INF	RD_NINF	undefined	unit	universe	Z_
" print() directives
syn keyword mupadDefine		Unquoted	NoNL	KeepOrder	Typeset
" domain specifics
syn keyword mupadStatement	domain	begin	end_domain	end
syn keyword mupadIdentifier	inherits	category	axiom	info	doc interface
" basic programming statements
syn keyword mupadStatement	proc	begin	end_proc
syn keyword mupadUnderlined	name	local	option	save
syn keyword mupadConditional	if	then	elif	else	end_if
syn keyword mupadConditional	case	of	do	break	end_case
syn keyword mupadRepeat		for	do	next	break	end_for
syn keyword mupadRepeat		while	do	next break end_while
syn keyword mupadRepeat		repeat	next break until	end_repeat
" domain packages/libraries
syn keyword mupadType			detools	import	linalg	numeric	numlib	plot	polylib
syn match mupadType				'\<DOM_\w*\>'

"syn keyword mupadFunction	contains
" Functions dealing with prime numbers
syn keyword mupadFunction	phi	invphi	mersenne	nextprime	numprimedivisors
syn keyword mupadFunction	pollard	prevprime	primedivisors
" Functions operating on Lists, Matrices, Sets, ...
syn keyword mupadFunction	array	_index
" Evaluation
syn keyword mupadFunction	float contains
" stdlib
syn keyword mupadFunction	_exprseq	_invert	_lazy_and	_lazy_or	_negate
syn keyword mupadFunction	_stmtseq	_invert	intersect	minus		union
syn keyword mupadFunction	Ci	D	Ei	O	Re	Im	RootOf	Si
syn keyword mupadFunction	Simplify
syn keyword mupadFunction	abs	airyAi	airyBi	alias	unalias	anames	append
syn keyword mupadFunction	arcsin	arccos	arctan	arccsc	arcsec	arccot
syn keyword mupadFunction	arcsinh	arccosh	arctanh	arccsch	arcsech	arccoth
syn keyword mupadFunction	arg	args	array	assert	assign	assignElements
syn keyword mupadFunction	assume	assuming	asympt	bernoulli
syn keyword mupadFunction	besselI	besselJ	besselK	besselY	beta	binomial	bool
syn keyword mupadFunction	bytes	card
syn keyword mupadFunction	ceil	floor	round	trunc
syn keyword mupadFunction	coeff	coerce	collect	combine	copyClosure
syn keyword mupadFunction	conjugate	content	context	contfrac
syn keyword mupadFunction	debug	degree	degreevec	delete	_delete	denom
syn keyword mupadFunction	densematrix	diff	dilog	dirac	discont	div	_div
syn keyword mupadFunction	divide	domtype	doprint	erf	erfc	error	eval	evalassign
syn keyword mupadFunction	evalp	exp	expand	export	unexport	expose	expr
syn keyword mupadFunction	expr2text	external	extnops	extop	extsubsop
syn keyword mupadFunction	fact	fact2	factor	fclose	finput	fname	fopen	fprint
syn keyword mupadFunction	fread	ftextinput	readbitmap	readdata	pathname
syn keyword mupadFunction	protocol	read	readbytes	write	writebytes
syn keyword mupadFunction	float	frac	frame	_frame	frandom	freeze	unfreeze
syn keyword mupadFunction	funcenv	gamma	gcd	gcdex	genident	genpoly
syn keyword mupadFunction	getpid	getprop	ground	has	hastype	heaviside	help
syn keyword mupadFunction	history	hold	hull	hypergeom	icontent	id
syn keyword mupadFunction	ifactor	igamma	igcd	igcdex	ilcm	in	_in
syn keyword mupadFunction	indets	indexval	info	input	int	int2text
syn keyword mupadFunction	interpolate	interval	irreducible	is
syn keyword mupadFunction	isprime	isqrt	iszero	ithprime	kummerU	lambertW
syn keyword mupadFunction	last	lasterror	lcm	lcoeff	ldegree	length
syn keyword mupadFunction	level	lhs	rhs	limit	linsolve	lllint
syn keyword mupadFunction	lmonomial	ln	loadmod	loadproc	log	lterm
syn keyword mupadFunction	match	map	mapcoeffs	maprat	matrix	max	min
syn keyword mupadFunction	mod	modp	mods	monomials	multcoeffs	new
syn keyword mupadFunction	newDomain	_next	nextprime	nops
syn keyword mupadFunction	norm	normal	nterms	nthcoeff	nthmonomial	nthterm
syn keyword mupadFunction	null	numer	ode	op	operator	package
syn keyword mupadFunction	pade	partfrac	patchlevel	pdivide
syn keyword mupadFunction	piecewise	plot	plotfunc2d	plotfunc3d
syn keyword mupadFunction	poly	poly2list	polylog	powermod	print
syn keyword mupadFunction	product	protect	psi	quit	_quit	radsimp	random	rationalize
syn keyword mupadFunction	rec	rectform	register	reset	return	revert
syn keyword mupadFunction	rewrite	select	series	setuserinfo	share	sign	signIm
syn keyword mupadFunction	simplify
syn keyword mupadFunction	sin	cos	tan	csc	sec	cot
syn keyword mupadFunction	sinh	cosh	tanh	csch	sech	coth
syn keyword mupadFunction	slot	solve
syn keyword mupadFunction	pdesolve	matlinsolve	matlinsolveLU	toeplitzSolve
syn keyword mupadFunction	vandermondeSolve	fsolve	odesolve	odesolve2
syn keyword mupadFunction	polyroots	polysysroots	odesolveGeometric
syn keyword mupadFunction	realroot	realroots	mroots	lincongruence
syn keyword mupadFunction	msqrts
syn keyword mupadFunction	sort	split	sqrt	strmatch	strprint
syn keyword mupadFunction	subs	subset	subsex	subsop	substring	sum
syn keyword mupadFunction	surd	sysname	sysorder	system	table	taylor	tbl2text
syn keyword mupadFunction	tcoeff	testargs	testeq	testtype	text2expr
syn keyword mupadFunction	text2int	text2list	text2tbl	rtime	time
syn keyword mupadFunction	traperror	type	unassume	unit	universe
syn keyword mupadFunction	unloadmod	unprotect	userinfo	val	version
syn keyword mupadFunction	warning	whittakerM	whittakerW	zeta	zip

" graphics  plot::
syn keyword mupadFunction	getDefault	setDefault	copy	modify	Arc2d	Arrow2d
syn keyword mupadFunction	Arrow3d	Bars2d	Bars3d	Box	Boxplot	Circle2d	Circle3d
syn keyword mupadFunction	Cone	Conformal	Curve2d	Curve3d	Cylinder	Cylindrical
syn keyword mupadFunction	Density	Ellipse2d	Function2d	Function3d	Hatch
syn keyword mupadFunction	Histogram2d	HOrbital	Implicit2d	Implicit3d
syn keyword mupadFunction	Inequality	Iteration	Line2d	Line3d	Lsys	Matrixplot
syn keyword mupadFunction	MuPADCube	Ode2d	Ode3d	Parallelogram2d	Parallelogram3d
syn keyword mupadFunction	Piechart2d	Piechart3d	Point2d	Point3d	Polar
syn keyword mupadFunction	Polygon2d	Polygon3d	Raster	Rectangle	Sphere
syn keyword mupadFunction	Ellipsoid	Spherical	Sum	Surface	SurfaceSet
syn keyword mupadFunction	SurfaceSTL	Tetrahedron	Hexahedron	Octahedron
syn keyword mupadFunction	Dodecahedron	Icosahedron	Text2d	Text3d	Tube	Turtle
syn keyword mupadFunction	VectorField2d	XRotate	ZRotate	Canvas	CoordinateSystem2d
syn keyword mupadFunction	CoordinateSystem3d	Group2d	Group3d	Scene2d	Scene3d	ClippingBox
syn keyword mupadFunction	Rotate2d	Rotate3d	Scale2d	Scale3d	Transform2d
syn keyword mupadFunction	Transform3d	Translate2d	Translate3d	AmbientLight
syn keyword mupadFunction	Camera	DistantLight	PointLight	SpotLight

" graphics Attributes
" graphics  Output Attributes
syn keyword mupadIdentifier	OutputFile	OutputOptions
" graphics  Defining Attributes
syn keyword mupadIdentifier	Angle	AngleRange	AngleBegin	AngleEnd
syn keyword mupadIdentifier	Area	Axis	AxisX	AxisY	AxisZ	Base	Top
syn keyword mupadIdentifier	BaseX	TopX	BaseY	TopY	BaseZ	TopZ
syn keyword mupadIdentifier	BaseRadius	TopRadius	Cells
syn keyword mupadIdentifier	Center	CenterX	CenterY	CenterZ
syn keyword mupadIdentifier	Closed	ColorData	CommandList	Contours	CoordinateType
syn keyword mupadIdentifier	Data	DensityData	DensityFunction	From	To
syn keyword mupadIdentifier	FromX	ToX	FromY	ToY	FromZ	ToZ
syn keyword mupadIdentifier	Function	FunctionX	FunctionY	FunctionZ
syn keyword mupadIdentifier	Function1	Function2	Baseline
syn keyword mupadIdentifier	Generations	RotationAngle	IterationRules	StartRule StepLength
syn keyword mupadIdentifier	TurtleRules	Ground	Heights	Moves	Inequalities
syn keyword mupadIdentifier	InputFile	Iterations	StartingPoint
syn keyword mupadIdentifier	LineColorFunction	FillColorFunction
syn keyword mupadIdentifier	Matrix2d	Matrix3d
syn keyword mupadIdentifier	MeshList	MeshListType	MeshListNormals
syn keyword mupadIdentifier	MagneticQuantumNumber	MomentumQuantumNumber	PrincipalQuantumNumber
syn keyword mupadIdentifier	Name	Normal	NormalX	NormalY	NormalZ
syn keyword mupadIdentifier	ParameterName	ParameterBegin	ParameterEnd	ParameterRange
syn keyword mupadIdentifier	Points2d	Points3d	Radius	RadiusFunction
syn keyword mupadIdentifier	Position	PositionX	PositionY	PositionZ
syn keyword mupadIdentifier	Scale	ScaleX	ScaleY	ScaleZ Shift	ShiftX	ShiftY	ShiftZ
syn keyword mupadIdentifier	SemiAxes	SemiAxisX	SemiAxisY	SemiAxisZ
syn keyword mupadIdentifier	Tangent1	Tangent1X	Tangent1Y	Tangent1Z
syn keyword mupadIdentifier	Tangent2	Tangent2X	Tangent2Y	Tangent2Z
syn keyword mupadIdentifier	Text	TextOrientation	TextRotation
syn keyword mupadIdentifier	UName	URange	UMin	UMax	VName	VRange	VMin	VMax
syn keyword mupadIdentifier	XName	XRange	XMin	XMax	YName	YRange	YMin	YMax
syn keyword mupadIdentifier	ZName	ZRange	ZMin	ZMax	ViewingBox
syn keyword mupadIdentifier	ViewingBoxXMin	ViewingBoxXMax	ViewingBoxXRange
syn keyword mupadIdentifier	ViewingBoxYMin	ViewingBoxYMax	ViewingBoxYRange
syn keyword mupadIdentifier	ViewingBoxZMin	ViewingBoxZMax	ViewingBoxZRange
syn keyword mupadIdentifier	Visible
" graphics  Axis Attributes
syn keyword mupadIdentifier	Axes	AxesInFront	AxesLineColor	AxesLineWidth
syn keyword mupadIdentifier	AxesOrigin	AxesOriginX	AxesOriginY	AxesOriginZ
syn keyword mupadIdentifier	AxesTips	AxesTitleAlignment
syn keyword mupadIdentifier	AxesTitleAlignmentX	AxesTitleAlignmentY	AxesTitleAlignmentZ
syn keyword mupadIdentifier	AxesTitles	XAxisTitle	YAxisTitle	ZAxisTitle
syn keyword mupadIdentifier	AxesVisible	XAxisVisible	YAxisVisible	ZAxisVisible
syn keyword mupadIdentifier	YAxisTitleOrientation
" graphics  Tick Marks Attributes
syn keyword mupadIdentifier	TicksAnchor	XTicksAnchor	YTicksAnchor	ZTicksAnchor
syn keyword mupadIdentifier	TicksAt	XTicksAt	YTicksAt	ZTicksAt
syn keyword mupadIdentifier	TicksBetween	XTicksBetween	YTicksBetween	ZTicksBetween
syn keyword mupadIdentifier	TicksDistance	XTicksDistance	YTicksDistance	ZTicksDistance
syn keyword mupadIdentifier	TicksNumber	XTicksNumber	YTicksNumber	ZTicksNumber
syn keyword mupadIdentifier	TicksVisible	XTicksVisible	YTicksVisible	ZTicksVisible
syn keyword mupadIdentifier	TicksLength	TicksLabelStyle
syn keyword mupadIdentifier	XTicksLabelStyle	YTicksLabelStyle	ZTicksLabelStyle
syn keyword mupadIdentifier	TicksLabelsVisible
syn keyword mupadIdentifier	XTicksLabelsVisible	YTicksLabelsVisible	ZTicksLabelsVisible
" graphics  Grid Lines Attributes
syn keyword mupadIdentifier	GridInFront	GridLineColor	SubgridLineColor
syn keyword mupadIdentifier	GridLineStyle	SubgridLineStyle GridLineWidth	SubgridLineWidth
syn keyword mupadIdentifier	GridVisible	XGridVisible	YGridVisible	ZGridVisible
syn keyword mupadIdentifier	SubgridVisible	XSubgridVisible	YSubgridVisible	ZSubgridVisible
" graphics  Animation Attributes
syn keyword mupadIdentifier	Frames	TimeRange	TimeBegin	TimeEnd
syn keyword mupadIdentifier	VisibleAfter	VisibleBefore	VisibleFromTo
syn keyword mupadIdentifier	VisibleAfterEnd	VisibleBeforeBegin
" graphics  Annotation Attributes
syn keyword mupadIdentifier	Footer	Header	FooterAlignment	HeaderAlignment
syn keyword mupadIdentifier	HorizontalAlignment	TitleAlignment	VerticalAlignment
syn keyword mupadIdentifier	Legend	LegendEntry	LegendText
syn keyword mupadIdentifier	LegendAlignment	LegendPlacement	LegendVisible
syn keyword mupadIdentifier	Title	Titles
syn keyword mupadIdentifier	TitlePosition	TitlePositionX	TitlePositionY	TitlePositionZ
" graphics  Layout Attributes
syn keyword mupadIdentifier	Bottom	Left	Height	Width	Layout	Rows	Columns
syn keyword mupadIdentifier	Margin	BottomMargin	TopMargin	LeftMargin	RightMargin
syn keyword mupadIdentifier	OutputUnits	Spacing
" graphics  Calculation Attributes
syn keyword mupadIdentifier	AdaptiveMesh	DiscontinuitySearch	Mesh	SubMesh
syn keyword mupadIdentifier	UMesh	USubMesh	VMesh	VSubMesh
syn keyword mupadIdentifier	XMesh	XSubMesh	YMesh	YSubMesh	Zmesh
" graphics  Camera and Lights Attributes
syn keyword mupadIdentifier	CameraCoordinates	CameraDirection
syn keyword mupadIdentifier	CameraDirectionX	CameraDirectionY	CameraDirectionZ
syn keyword mupadIdentifier	FocalPoint	FocalPointX	FocalPointY	FocalPointZ
syn keyword mupadIdentifier	LightColor	Lighting	LightIntensity	OrthogonalProjection
syn keyword mupadIdentifier	SpotAngle	ViewingAngle
syn keyword mupadIdentifier	Target	TargetX	TargetY	TargetZ
" graphics  Presentation Style and Fonts Attributes
syn keyword mupadIdentifier	ArrowLength
syn keyword mupadIdentifier	AxesTitleFont	FooterFont	HeaderFont	LegendFont
syn keyword mupadIdentifier	TextFont	TicksLabelFont	TitleFont
syn keyword mupadIdentifier	BackgroundColor	BackgroundColor2	BackgroundStyle
syn keyword mupadIdentifier	BackgroundTransparent	Billboarding	BorderColor	BorderWidth
syn keyword mupadIdentifier	BoxCenters	BoxWidths	DrawMode Gap	XGap	YGap
syn keyword mupadIdentifier	Notched	NotchWidth	Scaling	YXRatio	ZXRatio
syn keyword mupadIdentifier	VerticalAsymptotesVisible	VerticalAsymptotesStyle
syn keyword mupadIdentifier	VerticalAsymptotesColor	VerticalAsymptotesWidth
" graphics  Line Style Attributes
syn keyword mupadIdentifier	LineColor	LineColor2	LineColorType	LineStyle
syn keyword mupadIdentifier	LinesVisible	ULinesVisible	VLinesVisible	XLinesVisible
syn keyword mupadIdentifier	YLinesVisible	LineWidth	MeshVisible
" graphics  Point Style Attributes
syn keyword mupadIdentifier	PointColor	PointSize	PointStyle	PointsVisible
" graphics  Surface Style Attributes
syn keyword mupadIdentifier	BarStyle	Shadows	Color	Colors	FillColor	FillColor2
syn keyword mupadIdentifier	FillColorTrue	FillColorFalse	FillColorUnknown	FillColorType
syn keyword mupadIdentifier	Filled	FillPattern	FillPatterns	FillStyle
syn keyword mupadIdentifier	InterpolationStyle	Shading	UseNormals
" graphics  Arrow Style Attributes
syn keyword mupadIdentifier	TipAngle	TipLength	TipStyle	TubeDiameter
syn keyword mupadIdentifier	Tubular
" graphics  meta-documentation Attributes
syn keyword mupadIdentifier	objectGroupsListed

if version >= 508 || !exists("did_mupad_syntax_inits")
  if version < 508
    let did_mupad_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink mupadComment		Comment
  HiLink mupadString		String
  HiLink mupadOperator		Operator
  HiLink mupadSpecial		Special
  HiLink mupadStatement		Statement
  HiLink mupadUnderlined	Underlined
  HiLink mupadConditional	Conditional
  HiLink mupadRepeat		Repeat
  HiLink mupadFunction		Function
  HiLink mupadType		Type
  HiLink mupadDefine		Define
  HiLink mupadIdentifier	Identifier

  delcommand HiLink
endif

" TODO  More comprehensive listing.
