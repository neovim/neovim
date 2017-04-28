" Vim syntax file
" Language:	Metafont
" Maintainer:	Andreas Scherer <andreas.scherer@pobox.com>
" Last Change:	April 25, 2001

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Metafont 'primitives' as defined in chapter 25 of 'The METAFONTbook'
" Page 210: 'boolean expressions'
syn keyword mfBoolExp true false known unknown odd charexists not and or

" Page 210: 'numeric expression'
syn keyword mfNumExp normaldeviate length ASCII oct hex angle turningnumber
syn keyword mfNumExp totalweight directiontime xpart ypart xxpart xypart
syn keyword mfNumExp yxpart yypart sqrt sind cosd mlog mexp floor
syn keyword mfNumExp uniformdeviate

" Page 211: 'internal quantities'
syn keyword mfInternal tracingtitles tracingequations tracingcapsules
syn keyword mfInternal tracingchoices tracingspecs tracingpens
syn keyword mfInternal tracingcommands tracingrestores tracingmacros
syn keyword mfInternal tracingedges tracingoutput tracingonline tracingstats
syn keyword mfInternal pausing showstopping fontmaking proofing
syn keyword mfInternal turningcheck warningcheck smoothing autorounding
syn keyword mfInternal granularity fillin year month day time
syn keyword mfInternal charcode charext charwd charht chardp charic
syn keyword mfInternal chardx chardy designsize hppp vppp xoffset yoffset
syn keyword mfInternal boundarychar

" Page 212: 'pair expressions'
syn keyword mfPairExp point of precontrol postcontrol penoffset rotated
syn keyword mfPairExp scaled shifted slanted transformed xscaled yscaled
syn keyword mfPairExp zscaled

" Page 213: 'path expressions'
syn keyword mfPathExp makepath reverse subpath curl tension atleast
syn keyword mfPathExp controls cycle

" Page 214: 'pen expressions'
syn keyword mfPenExp nullpen pencircle makepen

" Page 214: 'picutre expressions'
syn keyword mfPicExp nullpicture

" Page 214: 'string expressions'
syn keyword mfStringExp jobname readstring str char decimal substring

" Page 217: 'commands and statements'
syn keyword mfCommand end dump save interim newinternal randomseed let
syn keyword mfCommand delimiters outer everyjob show showvariable showtoken
syn keyword mfCommand showdependencies showstats message errmessage errhelp
syn keyword mfCommand batchmode nonstopmode scrollmode errorstopmode
syn keyword mfCommand addto also contour doublepath withpen withweight cull
syn keyword mfCommand keeping dropping display inwindow openwindow at from to
syn keyword mfCommand shipout special numspecial

" Page 56: 'types'
syn keyword mfType boolean numeric pair path pen picture string transform

" Page 155: 'grouping'
syn keyword mfStatement begingroup endgroup

" Page 165: 'definitions'
syn keyword mfDefinition enddef def expr suffix text primary secondary
syn keyword mfDefinition tertiary vardef primarydef secondarydef tertiarydef

" Page 169: 'conditions and loops'
syn keyword mfCondition if fi else elseif endfor for forsuffixes forever
syn keyword mfCondition step until exitif

" Other primitives listed in the index
syn keyword mfPrimitive charlist endinput expandafter extensible
syn keyword mfPrimitive fontdimen headerbyte inner input intersectiontimes
syn keyword mfPrimitive kern ligtable quote scantokens skipto

" Keywords defined by plain.mf (defined on pp.262-278)
if !exists("plain_mf_macros")
  let plain_mf_macros = 1 " Set this to '0' if your source gets too colourful
			  " metapost.vim does so to turn off Metafont macros
endif
if plain_mf_macros
  syn keyword mfMacro abs addto_currentpicture aspect_ratio base_name
  syn keyword mfMacro base_version beginchar blacker blankpicture bot bye byte
  syn keyword mfMacro capsule_def ceiling change_width clear_pen_memory clearit
  syn keyword mfMacro clearpen clearxy counterclockwise culldraw cullit
  syn keyword mfMacro currentpen currentpen_path currentpicture
  syn keyword mfMacro currenttransform currentwindow cutdraw cutoff d decr
  syn keyword mfMacro define_blacker_pixels define_corrected_pixels
  syn keyword mfMacro define_good_x_pixels define_good_y_pixels
  syn keyword mfMacro define_horizontal_corrected_pixels define_pixels
  syn keyword mfMacro define_whole_blacker_pixels define_whole_pixels
  syn keyword mfMacro define_whole_vertical_blacker_pixels
  syn keyword mfMacro define_whole_vertical_pixels dir direction directionpoint
  syn keyword mfMacro displaying ditto div dotprod down downto draw drawdot
  syn keyword mfMacro endchar eps epsilon extra_beginchar extra_endchar
  syn keyword mfMacro extra_setup erase exitunless fill filldraw fix_units flex
  syn keyword mfMacro font_coding_scheme font_extra_space font_identifier
  syn keyword mfMacro font_normal_shrink font_normal_space font_normal_stretch
  syn keyword mfMacro font_quad font_setup font_size font_slant font_x_height
  syn keyword mfMacro fullcircle generate gfcorners gobble gobbled grayfont h
  syn keyword mfMacro halfcircle hide hround identity image_rules incr infinity
  syn keyword mfMacro interact interpath intersectionpoint inverse italcorr
  syn keyword mfMacro join_radius killtext labelfont labels left lft localfont
  syn keyword mfMacro loggingall lowres lowres_fix mag magstep makebox makegrid
  syn keyword mfMacro makelabel maketicks max min mod mode mode_def mode_name
  syn keyword mfMacro mode_setup nodisplays notransforms number_of_modes numtok
  syn keyword mfMacro o_correction openit origin pen_bot pen_lft pen_rt pen_top
  syn keyword mfMacro penlabels penpos penrazor penspeck pensquare penstroke
  syn keyword mfMacro pickup pixels_per_inch proof proofoffset proofrule
  syn keyword mfMacro proofrulethickness quartercircle range reflectedabout
  syn keyword mfMacro relax right rotatedabout rotatedaround round rt rulepen
  syn keyword mfMacro savepen screenchars screen_rows screen_cols screenrule
  syn keyword mfMacro screenstrokes shipit showit slantfont smode smoke softjoin
  syn keyword mfMacro solve stop superellipse takepower tensepath titlefont
  syn keyword mfMacro tolerance top tracingall tracingnone undraw undrawdot
  syn keyword mfMacro unfill unfilldraw unitpixel unitsquare unitvector up upto
  syn keyword mfMacro vround w whatever
endif

" Some other basic macro names, e.g., from cmbase, logo, etc.
if !exists("other_mf_macros")
  let other_mf_macros = 1 " Set this to '0' if your code gets too colourful
			  " metapost.vim does so to turn off Metafont macros
endif
if other_mf_macros
  syn keyword mfMacro beginlogochar
endif

" Numeric tokens
syn match mfNumeric	"[-]\=\d\+"
syn match mfNumeric	"[-]\=\.\d\+"
syn match mfNumeric	"[-]\=\d\+\.\d\+"

" Metafont lengths
syn match mfLength	"\<\(bp\|cc\|cm\|dd\|in\|mm\|pc\|pt\)\>"
syn match mfLength	"\<[-]\=\d\+\(bp\|cc\|cm\|dd\|in\|mm\|pc\|pt\)\#\=\>"
syn match mfLength	"\<[-]\=\.\d\+\(bp\|cc\|cm\|dd\|in\|mm\|pc\|pt\)\#\=\>"
syn match mfLength	"\<[-]\=\d\+\.\d\+\(bp\|cc\|cm\|dd\|in\|mm\|pc\|pt\)\#\=\>"

" Metafont coordinates and points
syn match mfCoord	"\<[xy]\d\+\>"
syn match mfPoint	"\<z\d\+\>"

" String constants
syn region mfString	start=+"+ end=+"+

" Comments:
syn match mfComment	"%.*$"

" synchronizing
syn sync maxlines=50

" Define the default highlighting
" Only when an item doesn't have highlighting yet

hi def link mfBoolExp	Statement
hi def link mfNumExp	Statement
hi def link mfInternal	Identifier
hi def link mfPairExp	Statement
hi def link mfPathExp	Statement
hi def link mfPenExp	Statement
hi def link mfPicExp	Statement
hi def link mfStringExp	Statement
hi def link mfCommand	Statement
hi def link mfType	Type
hi def link mfStatement	Statement
hi def link mfDefinition	Statement
hi def link mfCondition	Conditional
hi def link mfPrimitive	Statement
hi def link mfMacro	Macro
hi def link mfCoord	Identifier
hi def link mfPoint	Identifier
hi def link mfNumeric	Number
hi def link mfLength	Number
hi def link mfComment	Comment
hi def link mfString	String


let b:current_syntax = "mf"

" vim: ts=8
