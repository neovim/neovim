" Vim syntax file
" Language:	gnuplot 3.8i.0
" Maintainer:	John Hoelzel johnh51@users.sourceforge.net
" Last Change:	Mon May 26 02:33:33 UTC 2003
" Filenames:	*.gpi  *.gih   scripts: #!*gnuplot
" URL:		http://johnh51.get.to/vim/syntax/gnuplot.vim
"

" thanks to "David Necas (Yeti)" <yeti@physics.muni.cz> for heads up - working on more changes .
" *.gpi      = GnuPlot Input - what I use because there is no other guideline. jeh 11/2000
" *.gih      = makes using cut/pasting from gnuplot.gih easier ...
" #!*gnuplot = for Linux bash shell scripts of gnuplot commands.
"	       emacs used a suffix of '<gp?>'
" gnuplot demo files show no preference.
" I will post mail and newsgroup comments on a standard suffix in 'URL' directory.

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" some shortened names to make demo files look clean... jeh. 11/2000
" demos -> 3.8i ... jeh. 5/2003 - a work in progress...

" commands

syn keyword gnuplotStatement	cd call clear exit set unset plot splot help
syn keyword gnuplotStatement	load pause quit fit rep[lot] if
syn keyword gnuplotStatement	FIT_LIMIT FIT_MAXITER FIT_START_LAMBDA
syn keyword gnuplotStatement	FIT_LAMBDA_FACTOR FIT_LOG FIT_SCRIPT
syn keyword gnuplotStatement	print pwd reread reset save show test ! functions var
syn keyword gnuplotConditional	if
" if is cond + stmt - ok?

" numbers fm c.vim

"	integer number, or floating point number without a dot and with "f".
syn case    ignore
syn match   gnuplotNumber	"\<[0-9]\+\(u\=l\=\|lu\|f\)\>"
"	floating point number, with dot, optional exponent
syn match   gnuplotFloat	"\<[0-9]\+\.[0-9]*\(e[-+]\=[0-9]\+\)\=[fl]\=\>"
"	floating point number, starting with a dot, optional exponent
syn match   gnuplotFloat	"\.[0-9]\+\(e[-+]\=[0-9]\+\)\=[fl]\=\>"
"	floating point number, without dot, with exponent
syn match   gnuplotFloat	"\<[0-9]\+e[-+]\=[0-9]\+[fl]\=\>"
"	hex number
syn match   gnuplotNumber	"\<0x[0-9a-f]\+\(u\=l\=\|lu\)\>"
syn case    match
"	flag an octal number with wrong digits by not hilighting
syn match   gnuplotOctalError	"\<0[0-7]*[89]"

" plot args

syn keyword gnuplotType		u[sing] tit[le] notit[le] wi[th] steps fs[teps]
syn keyword gnuplotType		title notitle t
syn keyword gnuplotType		with w
syn keyword gnuplotType		li[nes] l
" t - too much?  w - too much?  l - too much?
syn keyword gnuplotType		linespoints via

" funcs

syn keyword gnuplotFunc		abs acos acosh arg asin asinh atan atanh atan2
syn keyword gnuplotFunc		besj0 besj1 besy0 besy1
syn keyword gnuplotFunc		ceil column cos cosh erf erfc exp floor gamma
syn keyword gnuplotFunc		ibeta inverf igamma imag invnorm int lgamma
syn keyword gnuplotFunc		log log10 norm rand real sgn sin sinh sqrt tan
syn keyword gnuplotFunc		lambertw
syn keyword gnuplotFunc		tanh valid
syn keyword gnuplotFunc		tm_hour tm_mday tm_min tm_mon tm_sec
syn keyword gnuplotFunc		tm_wday tm_yday tm_year

" set vars

syn keyword gnuplotType		xdata timefmt grid noytics ytics fs
syn keyword gnuplotType		logscale time notime mxtics nomxtics style mcbtics
syn keyword gnuplotType		nologscale
syn keyword gnuplotType		axes x1y2 unique acs[plines]
syn keyword gnuplotType		size origin multiplot xtics xr[ange] yr[ange] square nosquare ratio noratio
syn keyword gnuplotType		binary matrix index every thru sm[ooth]
syn keyword gnuplotType		all angles degrees radians
syn keyword gnuplotType		arrow noarrow autoscale noautoscale arrowstyle
" autoscale args = x y xy z t ymin ... - too much?
" needs code to: using title vs autoscale t
syn keyword gnuplotType		x y z zcb
syn keyword gnuplotType		linear  cubicspline  bspline order level[s]
syn keyword gnuplotType		auto disc[rete] incr[emental] from to head nohead
syn keyword gnuplotType		graph base both nosurface table out[put] data
syn keyword gnuplotType		bar border noborder boxwidth
syn keyword gnuplotType		clabel noclabel clip noclip cntrp[aram]
syn keyword gnuplotType		contour nocontour
syn keyword gnuplotType		dgrid3d nodgrid3d dummy encoding format
" set encoding args not included - yet.
syn keyword gnuplotType		function grid nogrid hidden[3d] nohidden[3d] isosample[s] key nokey
syn keyword gnuplotType		historysize nohistorysize
syn keyword gnuplotType		defaults offset nooffset trianglepattern undefined noundefined altdiagonal bentover noaltdiagonal nobentover
syn keyword gnuplotType		left right top bottom outside below samplen spacing width height box nobox linestyle ls linetype lt linewidth lw
syn keyword gnuplotType		Left Right autotitles noautotitles enhanced noenhanced
syn keyword gnuplotType		isosamples
syn keyword gnuplotType		label nolabel logscale nolog[scale] missing center font locale
syn keyword gnuplotType		mapping margin bmargin lmargin rmargin tmargin spherical cylindrical cartesian
syn keyword gnuplotType		linestyle nolinestyle linetype lt linewidth lw pointtype pt pointsize ps
syn keyword gnuplotType		mouse nomouse
syn keyword gnuplotType		nooffsets data candlesticks financebars linespoints lp vector nosurface
syn keyword gnuplotType		term[inal] linux aed767 aed512 gpic
syn keyword gnuplotType		regis tek410x tek40 vttek kc-tek40xx
syn keyword gnuplotType		km-tek40xx selanar bitgraph xlib x11 X11
" x11 args
syn keyword gnuplotType		aifm cgm dumb fig gif small large size nofontlist winword6 corel dxf emf
syn keyword gnuplotType		hpgl
" syn keyword gnuplotType	transparent hp2623a hp2648 hp500c pcl5				      why jeh
syn keyword gnuplotType		hp2623a hp2648 hp500c pcl5
syn match gnuplotType		"\<transparent\>"
syn keyword gnuplotType		hpljii hpdj hppj imagen mif pbm png svg
syn keyword gnuplotType		postscript enhanced_postscript qms table
" postscript editing values?
syn keyword gnuplotType		tgif tkcanvas epson-180dpi epson-60dpi
syn keyword gnuplotType		epson-lx800 nec-cp6 okidata starc
syn keyword gnuplotType		tandy-60dpi latex emtex pslatex pstex epslatex
syn keyword gnuplotType		eepic tpic pstricks texdraw mf metafont mpost mp
syn keyword gnuplotType		timestamp notimestamp
syn keyword gnuplotType		variables version
syn keyword gnuplotType		x2data y2data ydata zdata
syn keyword gnuplotType		reverse writeback noreverse nowriteback
syn keyword gnuplotType		axis mirror autofreq nomirror rotate autofreq norotate
syn keyword gnuplotType		update
syn keyword gnuplotType		multiplot nomultiplot mytics
syn keyword gnuplotType		nomytics mztics nomztics mx2tics nomx2tics
syn keyword gnuplotType		my2tics nomy2tics offsets origin output
syn keyword gnuplotType		para[metric] nopara[metric] pointsize polar nopolar
syn keyword gnuplotType		zrange x2range y2range rrange cbrange
syn keyword gnuplotType		trange urange vrange sample[s] size
syn keyword gnuplotType		bezier boxerrorbars boxes bargraph bar[s]
syn keyword gnuplotType		boxxy[errorbars] csplines dots fsteps histeps impulses
syn keyword gnuplotType		line[s] linesp[oints] points poiinttype sbezier splines steps
" w lt lw ls	      = optional
syn keyword gnuplotType		vectors xerr[orbars] xyerr[orbars] yerr[orbars] financebars candlesticks vector
syn keyword gnuplotType		errorb[ars] surface
syn keyword gnuplotType		filledcurve[s] pm3d   x1 x2 y1 y2 xy closed
syn keyword gnuplotType		at pi front
syn keyword gnuplotType		errorlines xerrorlines yerrorlines xyerrorlines
syn keyword gnuplotType		tics ticslevel ticscale time timefmt view
syn keyword gnuplotType		xdata xdtics noxdtics ydtics noydtics
syn keyword gnuplotType		zdtics nozdtics x2dtics nox2dtics y2dtics noy2dtics
syn keyword gnuplotType		xlab[el] ylab[el] zlab[el] cblab[el] x2label y2label xmtics
syn keyword gnuplotType		xmtics noxmtics ymtics noymtics zmtics nozmtics
syn keyword gnuplotType		x2mtics nox2mtics y2mtics noy2mtics
syn keyword gnuplotType		cbdtics nocbdtics cbmtics nocbmtics cbtics nocbtics
syn keyword gnuplotType		xtics noxtics ytics noytics
syn keyword gnuplotType		ztics noztics x2tics nox2tics
syn keyword gnuplotType		y2tics noy2tics zero nozero zeroaxis nozeroaxis
syn keyword gnuplotType		xzeroaxis noxzeroaxis yzeroaxis noyzeroaxis
syn keyword gnuplotType		x2zeroaxis nox2zeroaxis y2zeroaxis noy2zeroaxis
syn keyword gnuplotType		angles one two fill empty solid pattern
syn keyword gnuplotType		default
syn keyword gnuplotType		scansautomatic flush b[egin] noftriangles implicit
" b too much? - used in demo
syn keyword gnuplotType		palette positive negative ps_allcF nops_allcF maxcolors
syn keyword gnuplotType		push fontfile pop
syn keyword gnuplotType		rgbformulae defined file color model gradient colornames
syn keyword gnuplotType		RGB HSV CMY YIQ XYZ
syn keyword gnuplotType		colorbox vertical horizontal user bdefault
syn keyword gnuplotType		loadpath fontpath decimalsign in out

" comments + strings
syn region gnuplotComment	start="#" end="$"
syn region gnuplotComment	start=+"+ skip=+\\"+ end=+"+
syn region gnuplotComment	start=+'+	     end=+'+

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_gnuplot_syntax_inits")
  if version < 508
    let did_gnuplot_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink gnuplotStatement	Statement
  HiLink gnuplotConditional	Conditional
  HiLink gnuplotNumber		Number
  HiLink gnuplotFloat		Float
  HiLink gnuplotOctalError	Error
  HiLink gnuplotFunc		Type
  HiLink gnuplotType		Type
  HiLink gnuplotComment	Comment

  delcommand HiLink
endif

let b:current_syntax = "gnuplot"

" vim: ts=8
