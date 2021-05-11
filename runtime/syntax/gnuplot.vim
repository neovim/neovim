" Vim syntax file
" Language:	gnuplot 4.7.0
" Maintainer:	Josh Wainwright <wainwright DOT ja AT gmail DOT com>
" Last Maintainer:	Andrew Rasmussen andyras@users.sourceforge.net
" Original Maintainer:	John Hoelzel johnh51@users.sourceforge.net
" Last Change:	2020 May 12
" Filenames:	*.gnu *.plt *.gpi *.gih *.gp *.gnuplot scripts: #!*gnuplot
" URL:		http://www.vim.org/scripts/script.php?script_id=4873
" Original URL:	http://johnh51.get.to/vim/syntax/gnuplot.vim

" thanks to "David Necas (Yeti)" <yeti@physics.muni.cz>

" credit also to Jim Eberle <jim.eberle@fastnlight.com>
" for the script http://www.vim.org/scripts/script.php?script_id=1737

" some shortened names to make demo files look clean... jeh. 11/2000
" demos -> 3.8i ... jeh. 5/2003 - a work in progress...
" added current commands, keywords, variables, todos, macros... amr 2014-02-24

" For vim version 5.x: Clear all syntax items
" For vim version 6.x: Quit when a syntax file was already loaded

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" ---- Special characters ---- "

" no harm in just matching any \[char] within double quotes, right?
syn match gnuplotSpecial	"\\." contained
" syn match gnuplotSpecial	"\\\o\o\o\|\\x\x\x\|\\c[^"]\|\\[a-z\\]" contained

" measurements in the units in, cm and pt are special
syn match gnuplotUnit		"[0-9]+in"
syn match gnuplotUnit		"[0-9]+cm"
syn match gnuplotUnit		"[0-9]+pt"

" external (shell) commands are special
syn region gnuplotExternal	start="!" end="$"

" ---- Comments ---- "

syn region gnuplotComment	start="#" end="$" contains=gnuplotTodo

" ---- Constants ---- "

" strings
syn region gnuplotString	start=+"+ skip=+\\"+ end=+"+ contains=gnuplotSpecial
syn region gnuplotString	start="'" end="'"

" built-in variables
syn keyword gnuplotNumber	GNUTERM GPVAL_TERM GPVAL_TERMOPTIONS GPVAL_SPLOT
syn keyword gnuplotNumber	GPVAL_OUTPUT GPVAL_ENCODING GPVAL_VERSION
syn keyword gnuplotNumber	GPVAL_PATCHLEVEL GPVAL_COMPILE_OPTIONS
syn keyword gnuplotNumber	GPVAL_MULTIPLOT GPVAL_PLOT GPVAL_VIEW_ZSCALE
syn keyword gnuplotNumber	GPVAL_TERMINALS GPVAL_pi GPVAL_NaN
syn keyword gnuplotNumber	GPVAL_ERRNO GPVAL_ERRMSG GPVAL_PWD
syn keyword gnuplotNumber	pi NaN GPVAL_LAST_PLOT GPVAL_TERM_WINDOWID
syn keyword gnuplotNumber	GPVAL_X_MIN GPVAL_X_MAX GPVAL_X_LOG
syn keyword gnuplotNumber	GPVAL_DATA_X_MIN GPVAL_DATA_X_MAX GPVAL_Y_MIN
syn keyword gnuplotNumber	GPVAL_Y_MAX GPVAL_Y_LOG GPVAL_DATA_Y_MIN
syn keyword gnuplotNumber	GPVAL_DATA_Y_MAX GPVAL_X2_MIN GPVAL_X2_MAX
syn keyword gnuplotNumber	GPVAL_X2_LOG GPVAL_DATA_X2_MIN GPVAL_DATA_X2_MAX
syn keyword gnuplotNumber	GPVAL_Y2_MIN GPVAL_Y2_MAX GPVAL_Y2_LOG
syn keyword gnuplotNumber	GPVAL_DATA_Y2_MIN GPVAL_DATA_Y2_MAX GPVAL_Z_MIN
syn keyword gnuplotNumber	GPVAL_Z_MAX GPVAL_Z_LOG GPVAL_DATA_Z_MIN
syn keyword gnuplotNumber	GPVAL_DATA_Z_MAX GPVAL_CB_MIN GPVAL_CB_MAX
syn keyword gnuplotNumber	GPVAL_CB_LOG GPVAL_DATA_CB_MIN GPVAL_DATA_CB_MAX
syn keyword gnuplotNumber	GPVAL_T_MIN GPVAL_T_MAX GPVAL_T_LOG GPVAL_U_MIN
syn keyword gnuplotNumber	GPVAL_U_MAX GPVAL_U_LOG GPVAL_V_MIN GPVAL_V_MAX
syn keyword gnuplotNumber	GPVAL_V_LOG GPVAL_R_MIN GPVAL_R_LOG
syn keyword gnuplotNumber	GPVAL_TERM_XMIN GPVAL_TERM_XMAX GPVAL_TERM_YMIN
syn keyword gnuplotNumber	GPVAL_TERM_YMAX GPVAL_TERM_XSIZE
syn keyword gnuplotNumber	GPVAL_TERM_YSIZE GPVAL_VIEW_MAP GPVAL_VIEW_ROT_X
syn keyword gnuplotNumber	GPVAL_VIEW_ROT_Z GPVAL_VIEW_SCALE

" function name variables
syn match gnuplotNumber		"GPFUN_[a-zA-Z_]*"

" stats variables
syn keyword gnuplotNumber	STATS_records STATS_outofrange STATS_invalid
syn keyword gnuplotNumber	STATS_blank STATS_blocks STATS_columns STATS_min
syn keyword gnuplotNumber	STATS_max STATS_index_min STATS_index_max
syn keyword gnuplotNumber	STATS_lo_quartile STATS_median STATS_up_quartile
syn keyword gnuplotNumber	STATS_mean STATS_stddev STATS_sum STATS_sumsq
syn keyword gnuplotNumber	STATS_correlation STATS_slope STATS_intercept
syn keyword gnuplotNumber	STATS_sumxy STATS_pos_min_y STATS_pos_max_y
syn keyword gnuplotNumber	STATS_mean STATS_stddev STATS_mean_x STATS_sum_x
syn keyword gnuplotNumber	STATS_stddev_x STATS_sumsq_x STATS_min_x
syn keyword gnuplotNumber	STATS_max_x STATS_median_x STATS_lo_quartile_x
syn keyword gnuplotNumber	STATS_up_quartile_x STATS_index_min_x
syn keyword gnuplotNumber	STATS_index_max_x STATS_mean_y STATS_stddev_y
syn keyword gnuplotNumber	STATS_sum_y STATS_sumsq_y STATS_min_y
syn keyword gnuplotNumber	STATS_max_y STATS_median_y STATS_lo_quartile_y
syn keyword gnuplotNumber	STATS_up_quartile_y STATS_index_min_y
syn keyword gnuplotNumber	STATS_index_max_y STATS_correlation STATS_sumxy

" deprecated fit variables
syn keyword gnuplotError	FIT_LIMIT FIT_MAXITER FIT_START_LAMBDA
syn keyword gnuplotError	FIT_LAMBDA_FACTOR FIT_LOG FIT_SCRIPT

" numbers, from c.vim

" integer number, or floating point number without a dot and with "f".
syn case    ignore
syn match   gnuplotNumber	"\<[0-9]\+\(u\=l\=\|lu\|f\)\>"

" floating point number, with dot, optional exponent
syn match   gnuplotFloat	"\<[0-9]\+\.[0-9]*\(e[-+]\=[0-9]\+\)\=[fl]\=\>"

" floating point number, starting with a dot, optional exponent
syn match   gnuplotFloat	"\.[0-9]\+\(e[-+]\=[0-9]\+\)\=[fl]\=\>"

" floating point number, without dot, with exponent
syn match   gnuplotFloat	"\<[0-9]\+e[-+]\=[0-9]\+[fl]\=\>"

" hex number
syn match   gnuplotNumber	"\<0x[0-9a-f]\+\(u\=l\=\|lu\)\>"
syn case    match

" flag an octal number with wrong digits by not highlighting
syn match   gnuplotOctalError	"\<0[0-7]*[89]"

" ---- Identifiers: Functions ---- "

" numerical functions
syn keyword gnuplotFunc		abs acos acosh airy arg asin asinh atan atan2
syn keyword gnuplotFunc		atanh EllipticK EllipticE EllipticPi besj0 besj1
syn keyword gnuplotFunc		besy0 besy1 ceil cos cosh erf erfc exp expint
syn keyword gnuplotFunc		floor gamma ibeta inverf igamma imag invnorm int
syn keyword gnuplotFunc		lambertw lgamma log log10 norm rand real sgn sin
syn keyword gnuplotFunc		sin sinh sqrt tan tanh voigt

" string functions
syn keyword gnuplotFunc		gprintf sprintf strlen strstrt substr strftime
syn keyword gnuplotFunc		strptime system word words

" other functions
syn keyword gnuplotFunc		column columnhead columnheader defined exists
syn keyword gnuplotFunc		hsv2rgb stringcolumn timecolumn tm_hour tm_mday
syn keyword gnuplotFunc		tm_min tm_mon tm_sec tm_wday tm_yday tm_year
syn keyword gnuplotFunc		time valid value

" ---- Statements ---- "

" common (builtin) variable names
syn keyword gnuplotKeyword	x y t u v z s

" conditionals
syn keyword gnuplotConditional	if else

" repeats
syn keyword gnuplotRepeat	do for while

" operators
syn match gnuplotOperator	"[-+*/^|&?:]"
syn match gnuplotOperator	"\*\*"
syn match gnuplotOperator	"&&"
syn match gnuplotOperator	"||"

" Keywords

" keywords for 'fit' command
syn keyword gnuplotKeyword	via z x:z x:z:s x:y:z:s
syn keyword gnuplotKeyword	x:y:t:z:s x:y:t:u:z:s x:y:t:u:v:z:s

" keywords for 'plot' command
" 'axes' keyword
syn keyword gnuplotKeyword	axes x1y1 x1y2 x2y1 x2y2
" 'binary' keyword
syn keyword gnuplotKeyword	binary matrix general array record format endian
syn keyword gnuplotKeyword	filetype avs edf png scan transpose dx dy dz
syn keyword gnuplotKeyword	flipx flipy flipz origin center rotate using
syn keyword gnuplotKeyword	perpendicular skip every
" datafile keywords
syn keyword gnuplotKeyword	binary nonuniform matrix index every using
syn keyword gnuplotKeyword	smooth volatile noautoscale every index
" 'smooth' keywords
syn keyword gnuplotKeyword	unique frequency cumulative cnormal kdensity
syn keyword gnuplotKeyword	csplines acsplines bezer sbezier
" deprecated 'thru' keyword
syn keyword gnuplotError	thru
" 'using' keyword
syn keyword gnuplotKeyword	using u xticlabels yticlabels zticlabels
syn keyword gnuplotKeyword	x2ticlabels y2ticlabels xtic ytic ztic
" 'errorbars' keywords
syn keyword gnuplotKeyword	errorbars xerrorbars yerrorbars xyerrorbars
" 'errorlines' keywords
syn keyword gnuplotKeyword	errorlines xerrorlines yerrorlines xyerrorlines
" 'title' keywords
syn keyword gnuplotKeyword	title t tit notitle columnheader at beginning
syn keyword gnuplotKeyword	end
" 'with' keywords
syn keyword gnuplotKeyword	with w linestyle ls linetype lt linewidth
syn keyword gnuplotKeyword	lw linecolor lc pointtype pt pointsize ps
syn keyword gnuplotKeyword	fill fs nohidden3d nocontours nosurface palette
" styles for 'with'
syn keyword gnuplotKeyword	lines l points p linespoints lp surface dots
syn keyword gnuplotKeyword	impulses labels vectors steps fsteps histeps
syn keyword gnuplotKeyword	errorbars errorlines financebars xerrorbars
syn keyword gnuplotKeyword	xerrorlines xyerrorbars yerrorbars yerrorlines
syn keyword gnuplotKeyword	boxes boxerrorbars boxxyerrorbars boxplot
syn keyword gnuplotKeyword	candlesticks circles ellipses filledcurves
syn keyword gnuplotKeyword	histogram image rgbimage rgbalpha pm3d variable

" keywords for 'save' command
syn keyword gnuplotKeyword	save functions func variables all var terminal
syn keyword gnuplotKeyword	term set

" keywords for 'set/show' command
" set angles
syn keyword gnuplotKeyword	angles degrees deg radians rad
" set arrow
syn keyword gnuplotKeyword	arrow from to rto length angle arrowstyle as
syn keyword gnuplotKeyword	nohead head backhead heads size filled empty
syn keyword gnuplotKeyword	nofilled front back linestyle linetype linewidth
" set autoscale
" TODO regexp here
syn keyword gnuplotKeyword	autoscale x y z cb x2 y2 zy min max fixmin
syn keyword gnuplotKeyword	fixmax fix keepfix noextend
" set bars
syn keyword gnuplotKeyword	bars small large fullwidth front back
" set bind
syn keyword gnuplotKeyword	bind
" set margins
" TODO regexp
syn keyword gnuplotKeyword	margin bmargin lmargin rmargin tmargin
" set border
syn keyword gnuplotKeyword	border front back
" set boxwidth
syn keyword gnuplotKeyword	boxwidth absolute relative
" deprecated set clabel
syn keyword gnuplotError	clabel
" set clip
syn keyword gnuplotKeyword	clip points one two
" set cntrlabel
syn keyword gnuplotKeyword	cntrlabel format font start interval onecolor
" set cntrparam
syn keyword gnuplotKeyword	cntrparam linear cubicspline bspline points
syn keyword gnuplotKeyword	order levels auto discrete incremental
" set colorbox
syn keyword gnuplotKeyword	colorbox vertical horizontal default user origin
syn keyword gnuplotKeyword	size front back noborder bdefault border
" show colornames
syn keyword gnuplotKeyword	colornames
" set contour
syn keyword gnuplotKeyword	contour base surface both
" set datafile
syn keyword gnuplotKeyword	datafile fortran nofpe_trap missing separator
syn keyword gnuplotKeyword	whitespace tab comma commentschars binary
" set decimalsign
syn keyword gnuplotKeyword	decimalsign locale
" set dgrid3d
syn keyword gnuplotKeyword	dgrid3d splines qnorm gauss cauchy exp box hann
syn keyword gnuplotKeyword	kdensity
" set dummy
syn keyword gnuplotKeyword	dummy
" set encoding
syn keyword gnuplotKeyword	encoding default iso_8859_1 iso_8859_15
syn keyword gnuplotKeyword	iso_8859_2 iso_8859_9 koi8r koi8u cp437 cp850
syn keyword gnuplotKeyword	cp852 cp950 cp1250 cp1251 cp1254 sjis utf8
" set fit
syn keyword gnuplotKeyword	fit logfile default quiet noquiet results brief
syn keyword gnuplotKeyword	verbose errorvariables noerrorvariables
syn keyword gnuplotKeyword	errorscaling noerrorscaling prescale noprescale
syn keyword gnuplotKeyword	maxiter none limit limit_abs start-lambda script
syn keyword gnuplotKeyword	lambda-factor
" set fontpath
syn keyword gnuplotKeyword	fontpath
" set format
syn keyword gnuplotKeyword	format
" show functions
syn keyword gnuplotKeyword	functions
" set grid
syn keyword gnuplotKeyword	grid polar layerdefault xtics ytics ztics x2tics
syn keyword gnuplotKeyword	y2tics cbtics mxtics mytics mztics mx2tics
syn keyword gnuplotKeyword	my2tics mcbtics xmtics ymtics zmtics x2mtics
syn keyword gnuplotKeyword	y2mtics cbmtics noxtics noytics noztics nox2tics
syn keyword gnuplotKeyword	noy2tics nocbtics nomxtics nomytics nomztics
syn keyword gnuplotKeyword	nomx2tics nomy2tics nomcbtics
" set hidden3d
syn keyword gnuplotKeyword	hidden3d offset trianglepattern undefined
syn keyword gnuplotKeyword	altdiagonal noaltdiagonal bentover nobentover
syn keyword gnuplotKeyword	noundefined
" set historysize
syn keyword gnuplotKeyword	historysize
" set isosamples
syn keyword gnuplotKeyword	isosamples
" set key
syn keyword gnuplotKeyword	key on off inside outside at left right center
syn keyword gnuplotKeyword	top bottom vertical horizontal Left Right
syn keyword gnuplotKeyword	opaque noopaque reverse noreverse invert maxrows
syn keyword gnuplotKeyword	noinvert samplen spacing width height autotitle
syn keyword gnuplotKeyword	noautotitle title enhanced noenhanced font
syn keyword gnuplotKeyword	textcolor box nobox linetype linewidth maxcols
" set label
syn keyword gnuplotKeyword	label left center right rotate norotate by font
syn keyword gnuplotKeyword	front back textcolor point nopoint offset boxed
syn keyword gnuplotKeyword	hypertext
" set linetype
syn keyword gnuplotKeyword	linetype
" set link
syn keyword gnuplotKeyword	link via inverse
" set loadpath
syn keyword gnuplotKeyword	loadpath
" set locale
syn keyword gnuplotKeyword	locale
" set logscale
syn keyword gnuplotKeyword	logscale log
" set macros
syn keyword gnuplotKeyword	macros
" set mapping
syn keyword gnuplotKeyword	mapping cartesian spherical cylindrical
" set mouse
syn keyword gnuplotKeyword	mouse doubleclick nodoubleclick zoomcoordinates
syn keyword gnuplotKeyword	nozoomcoordinates ruler noruler at polardistance
syn keyword gnuplotKeyword	nopolardistance deg tan format clipboardformat
syn keyword gnuplotKeyword	mouseformat labels nolabels zoomjump nozoomjump
syn keyword gnuplotKeyword	verbose noverbose
" set multiplot
syn keyword gnuplotKeyword	multiplot title font layout rowsfirst downwards
syn keyword gnuplotKeyword	downwards upwards scale offset
" set object
syn keyword gnuplotKeyword	object behind fillcolor fc fs rectangle ellipse
syn keyword gnuplotKeyword	circle polygon at center size units xy xx yy to
syn keyword gnuplotKeyword	from
" set offsets
syn keyword gnuplotKeyword	offsets
" set origin
syn keyword gnuplotKeyword	origin
" set output
syn keyword gnuplotKeyword	output
" set parametric
syn keyword gnuplotKeyword	parametric
" show plot
syn keyword gnuplotKeyword	plot add2history
" set pm3d
syn keyword gnuplotKeyword	hidden3d interpolate scansautomatic scansforward
syn keyword gnuplotKeyword	scansbackward depthorder flush begin center end
syn keyword gnuplotKeyword	ftriangles noftriangles clip1in clip4in mean map
syn keyword gnuplotKeyword	corners2color geomean harmean rms median min max
syn keyword gnuplotKeyword	c1 c2 c3 c4 pm3d at nohidden3d implicit explicit
" set palette
syn keyword gnuplotKeyword	palette gray color gamma rgbformulae defined
syn keyword gnuplotKeyword	file functions cubehelix start cycles saturation
syn keyword gnuplotKeyword	model RGB HSV CMY YIQ XYZ positive negative
syn keyword gnuplotKeyword	nops_allcF ps_allcF maxcolors float int gradient
syn keyword gnuplotKeyword	fit2rgbformulae rgbformulae
" set pointintervalbox
syn keyword gnuplotKeyword	pointintervalbox
" set pointsize
syn keyword gnuplotKeyword	pointsize
" set polar
syn keyword gnuplotKeyword	polar
" set print
syn keyword gnuplotKeyword	print append
" set psdir
syn keyword gnuplotKeyword	psdir
" set raxis
syn keyword gnuplotKeyword	raxis rrange rtics
" set samples
syn keyword gnuplotKeyword	samples
" set size
syn keyword gnuplotKeyword	size square nosquare ratio noratio
" set style
syn keyword gnuplotKeyword	style arrow auto back border boxplot
syn keyword gnuplotKeyword	candlesticks circle clustered columnstacked data
syn keyword gnuplotKeyword	default ellipse empty fill[ed] financebars
syn keyword gnuplotKeyword	fraction front function gap graph head[s]
syn keyword gnuplotKeyword	histogram increment labels lc line linecolor
syn keyword gnuplotKeyword	linetype linewidth lt lw noborder nofilled
syn keyword gnuplotKeyword	nohead nooutliers nowedge off opaque outliers
syn keyword gnuplotKeyword	palette pattern pi pointinterval pointsize
syn keyword gnuplotKeyword	pointtype ps pt radius range rectangle
syn keyword gnuplotKeyword	rowstacked screen separation size solid sorted
syn keyword gnuplotKeyword	textbox transparent units unsorted userstyles
syn keyword gnuplotKeyword	wedge x x2 xx xy yy
" set surface
syn keyword gnuplotKeyword	surface implicit explicit
" set table
syn keyword gnuplotKeyword	table
" set terminal (list of terminals)
syn keyword gnuplotKeyword	terminal term push pop aed512 aed767 aifm aqua
syn keyword gnuplotKeyword	be cairo cairolatex canvas cgm context corel
syn keyword gnuplotKeyword	debug dumb dxf dxy800a eepic emf emxvga epscairo
syn keyword gnuplotKeyword	epslatex epson_180dpi excl fig ggi gif gpic hpgl
syn keyword gnuplotKeyword	grass hp2623a hp2648 hp500c hpljii hppj imagen
syn keyword gnuplotKeyword	jpeg kyo latex linux lua mf mif mp next openstep
syn keyword gnuplotKeyword	pbm pdf pdfcairo pm png pngcairo postscript
syn keyword gnuplotKeyword	pslatex pstex pstricks qms qt regis sun svg svga
syn keyword gnuplotKeyword	tek40 tek410x texdraw tgif tikz tkcanvas tpic
syn keyword gnuplotKeyword	vgagl vws vx384 windows wx wxt x11 xlib
" keywords for 'set terminal'
syn keyword gnuplotKeyword	color monochrome dashlength dl eps pdf fontscale
syn keyword gnuplotKeyword	standalone blacktext colortext colourtext header
syn keyword gnuplotKeyword	noheader mono color solid dashed notransparent
syn keyword gnuplotKeyword	crop crop background input rounded butt square
syn keyword gnuplotKeyword	size fsize standalone name jsdir defaultsize
syn keyword gnuplotKeyword	timestamp notimestamp colour mitered beveled
syn keyword gnuplotKeyword	round squared palfuncparam blacktext nec_cp6
syn keyword gnuplotKeyword	mppoints inlineimages externalimages defaultfont
syn keyword gnuplotKeyword	aspect feed nofeed rotate small tiny standalone
syn keyword gnuplotKeyword	oldstyle newstyle level1 leveldefault level3
syn keyword gnuplotKeyword	background nobackground solid clip noclip
syn keyword gnuplotKeyword	colortext colourtext epson_60dpi epson_lx800
syn keyword gnuplotKeyword	okidata starc tandy_60dpi dpu414 nec_cp6 draft
syn keyword gnuplotKeyword	medium large normal landscape portrait big
syn keyword gnuplotKeyword	inches pointsmax textspecial texthidden
syn keyword gnuplotKeyword	thickness depth version acceleration giant
syn keyword gnuplotKeyword	delay loop optimize nooptimize pspoints
syn keyword gnuplotKeyword	FNT9X17 FNT13X25 interlace nointerlace courier
syn keyword gnuplotKeyword	originreset nooriginreset gparrows nogparrows
syn keyword gnuplotKeyword	picenvironment nopicenvironment tightboundingbox
syn keyword gnuplotKeyword	notightboundingbox charsize gppoints nogppoints
syn keyword gnuplotKeyword	fontscale textscale fulldoc nofulldoc standalone
syn keyword gnuplotKeyword	preamble header tikzplot tikzarrows notikzarrows
syn keyword gnuplotKeyword	cmykimages externalimages noexternalimages
syn keyword gnuplotKeyword	polyline vectors magnification psnfss nopsnfss
syn keyword gnuplotKeyword	psnfss-version7 prologues a4paper amstex fname
syn keyword gnuplotKeyword	fsize server persist widelines interlace
syn keyword gnuplotKeyword	truecolor notruecolor defaultplex simplex duplex
syn keyword gnuplotKeyword	nofontfiles adobeglyphnames noadobeglyphnames
syn keyword gnuplotKeyword	nostandalone metric textrigid animate nopspoints
syn keyword gnuplotKeyword	hpdj FNT5X9 roman emtex rgbimages bitmap
syn keyword gnuplotKeyword	nobitmap providevars nointerlace add delete
syn keyword gnuplotKeyword	auxfile hacktext unit raise palfuncparam
syn keyword gnuplotKeyword	noauxfile nohacktext nounit noraise ctrl noctrl
syn keyword gnuplotKeyword	close widget fixed dynamic tek40xx vttek
syn keyword gnuplotKeyword	kc-tek40xx km-tek40xx bitgraph perltk
syn keyword gnuplotKeyword	interactive red green blue interpolate mode
syn keyword gnuplotKeyword	position ctrlq replotonresize position noctrlq
syn keyword gnuplotKeyword	noreplotonresize
" set termoption
syn keyword gnuplotKeyword	termoption font fontscale solid dashed
" set tics
syn keyword gnuplotKeyword	tics add axis border mirror nomirror in out
syn keyword gnuplotKeyword	scale rotate norotate by offset nooffset left
syn keyword gnuplotKeyword	autojustify format font textcolor right center
" deprecated set ticslevel
syn keyword gnuplotError	ticslevel ticscale
" set timestamp
syn keyword gnuplotKeyword	timestamp top bottom offset font
" set timefmt
syn keyword gnuplotKeyword	timefmt
" set title
syn keyword gnuplotKeyword	title offset font textcolor tc
" set ranges
syn keyword gnuplotKeyword	trange urange vrange
" show variables
syn keyword gnuplotKeyword	variables
" show version
syn keyword gnuplotKeyword	version
" set view
syn keyword gnuplotKeyword	view map equal noequal xy xyz
" set x2data
syn keyword gnuplotKeyword	xdata ydata zdata x2data y2data cbdata xdtics
syn keyword gnuplotKeyword	ydtics zdtics x2dtics y2dtics cbdtics xzeroaxis
syn keyword gnuplotKeyword	yzeroaxis zzeroaxis x2zeroaxis y2zeroaxis
syn keyword gnuplotKeyword	cbzeroaxis time geographic
" set label
syn keyword gnuplotKeyword	xlabel ylabel zlabel x2label y2label cblabel
syn keyword gnuplotKeyword	offset font textcolor by parallel
" set range
syn keyword gnuplotKeyword	xrange yrange zrange x2range y2range cbrange
" set xyplane
syn keyword gnuplotKeyword	xyplane
" set zeroaxis
" set zero
syn keyword gnuplotKeyword	zero
" set zeroaxis
syn keyword gnuplotKeyword	zeroaxis

" keywords for 'stats' command
syn keyword gnuplotKeyword	nooutput

" keywords for 'test' command
syn keyword gnuplotKeyword	terminal palette rgb rbg grb gbr brg bgr

" ---- Macros ---- "

syn match gnuplotMacro		"@[a-zA-Z0-9_]*"

" ---- Todos ---- "

syn keyword gnuplotTodo		contained TODO FIXME XXX

" ---- Types: gnuplot commands ---- "

" I set the commands as Types to distinguish them visually from keywords for the
" commands.  This comes at the end of the syntax file because some commands
" are redundant with keywords.  It's probably too much trouble to go and
" create special regions for each redundant keyword/command pair, which means
" that some keywords (e.g. 'p') will be highlighted as commands.

syn keyword gnuplotStatement	cd call clear evaluate exit fit help history
syn keyword gnuplotStatement	load lower pause plot p print pwd quit raise
syn keyword gnuplotStatement	refresh replot rep reread reset save set show
syn keyword gnuplotStatement	shell splot spstats stats system test undefine
syn keyword gnuplotStatement	unset update

" ---- Define the default highlighting ---- "
" Only when an item doesn't have highlighting yet

" ---- Comments ---- "
hi def link gnuplotComment		Comment

" ---- Constants ---- "
hi def link gnuplotString		String
hi def link gnuplotNumber		Number
hi def link gnuplotFloat		Float

" ---- Identifiers ---- "
hi def link gnuplotIdentifier	Identifier

" ---- Statements ---- "
hi def link gnuplotConditional	Conditional
hi def link gnuplotRepeat		Repeat
hi def link gnuplotKeyword		Keyword
hi def link gnuplotOperator	Operator

" ---- PreProcs ---- "
hi def link gnuplotMacro		Macro

" ---- Types ---- "
hi def link gnuplotStatement	Type
hi def link gnuplotFunc		Identifier

" ---- Specials ---- "
hi def link gnuplotSpecial		Special
hi def link gnuplotUnit		Special
hi def link gnuplotExternal	Special

" ---- Errors ---- "
hi def link gnuplotError		Error
hi def link gnuplotOctalError	Error

" ---- Todos ---- "
hi def link gnuplotTodo		Todo


let b:current_syntax = "gnuplot"

" vim: ts=8
