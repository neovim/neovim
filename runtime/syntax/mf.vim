" Vim syntax file
" Language:           METAFONT
" Maintainer:         Nicola Vitacolonna <nvitacolonna@gmail.com>
" Former Maintainers: Andreas Scherer <andreas.scherer@pobox.com>
" Last Change:        2016 Oct 1

if exists("b:current_syntax")
  finish
endif

syn iskeyword @,_

" METAFONT 'primitives' as defined in chapter 25 of 'The METAFONTbook'
" Page 210: 'boolean expressions'
syn keyword mfBoolExp        and charexists false known not odd or true unknown

" Page 210: 'numeric expression'
syn keyword mfNumExp         ASCII angle cosd directiontime floor hex length
syn keyword mfNumExp         mexp mlog normaldeviate oct sind sqrt totalweight
syn keyword mfNumExp         turningnumber uniformdeviate xpart xxpart xypart
syn keyword mfNumExp         ypart yxpart yypart

" Page 211: 'internal quantities'
syn keyword mfInternal       autorounding boundarychar charcode chardp chardx
syn keyword mfInternal       chardy charext charht charic charwd day designsize
syn keyword mfInternal       fillin fontmaking granularity hppp jobname month
syn keyword mfInternal       pausing proofing showstopping smoothing time
syn keyword mfInternal       tracingcapsules tracingchoices tracingcommands
syn keyword mfInternal       tracingedges tracingequations tracingmacros
syn keyword mfInternal       tracingonline tracingoutput tracingpens
syn keyword mfInternal       tracingrestores tracingspecs tracingstats
syn keyword mfInternal       tracingtitles turningcheck vppp warningcheck
syn keyword mfInternal       xoffset year yoffset

" Page 212: 'pair expressions'
syn keyword mfPairExp        of penoffset point postcontrol precontrol rotated
syn keyword mfPairExp        scaled shifted slanted transformed xscaled yscaled
syn keyword mfPairExp        zscaled

" Page 213: 'path expressions'
syn keyword mfPathExp        atleast controls curl cycle makepath reverse
syn keyword mfPathExp        subpath tension

" Page 214: 'pen expressions'
syn keyword mfPenExp         makepen nullpen pencircle

" Page 214: 'picture expressions'
syn keyword mfPicExp         nullpicture

" Page 214: 'string expressions'
syn keyword mfStringExp      char decimal readstring str substring

" Page 217: 'commands and statements'
syn keyword mfCommand        addto also at batchmode contour cull delimiters
syn keyword mfCommand        display doublepath dropping dump end errhelp
syn keyword mfCommand        errmessage errorstopmode everyjob from interim
syn keyword mfCommand        inwindow keeping let message newinternal
syn keyword mfCommand        nonstopmode numspecial openwindow outer randomseed
syn keyword mfCommand        save scrollmode shipout show showdependencies
syn keyword mfCommand        showstats showtoken showvariable special to withpen
syn keyword mfCommand        withweight

" Page 56: 'types'
syn keyword mfType           boolean numeric pair path pen picture string
syn keyword mfType           transform

" Page 155: 'grouping'
syn keyword mfStatement      begingroup endgroup

" Page 165: 'definitions'
syn keyword mfDefinition     def enddef expr primary primarydef secondary
syn keyword mfDefinition     secondarydef suffix tertiary tertiarydef text
syn keyword mfDefinition     vardef

" Page 169: 'conditions and loops'
syn keyword mfCondition      else elseif endfor exitif fi for forever
syn keyword mfCondition      forsuffixes if step until

" Other primitives listed in the index
syn keyword mfPrimitive      charlist endinput expandafter extensible fontdimen
syn keyword mfPrimitive      headerbyte inner input intersectiontimes kern
syn keyword mfPrimitive      ligtable quote scantokens skipto

" Implicit suffix parameters
syn match   mfSuffixParam    "@#\|#@\|@"

" These are just tags, but given their special status, we
" highlight them as variables
syn keyword mfVariable       x y

" Keywords defined by plain.mf (defined on pp.262-278)
if get(g:, "plain_mf_macros", 1)
  syn keyword mfDef          addto_currentpicture beginchar capsule_def
  syn keyword mfDef          change_width clear_pen_memory clearit clearpen
  syn keyword mfDef          clearxy culldraw cullit cutdraw
  syn keyword mfDef          define_blacker_pixels define_corrected_pixels
  syn keyword mfDef          define_good_x_pixels define_good_y_pixels
  syn keyword mfDef          define_horizontal_corrected_pixels define_pixels
  syn keyword mfDef          define_whole_blacker_pixels define_whole_pixels
  syn keyword mfDef          define_whole_vertical_blacker_pixels
  syn keyword mfDef          define_whole_vertical_pixels downto draw drawdot
  syn keyword mfDef          endchar erase exitunless fill filldraw fix_units
  syn keyword mfDef          flex font_coding_scheme font_extra_space
  syn keyword mfDef          font_identifier font_normal_shrink
  syn keyword mfDef          font_normal_space font_normal_stretch font_quad
  syn keyword mfDef          font_size font_slant font_x_height gfcorners gobble
  syn keyword mfDef          hide imagerules interact italcorr killtext
  syn keyword mfDef          loggingall lowres_fix makebox makegrid maketicks
  syn keyword mfDef          mode_def mode_setup nodisplays notransforms numtok
  syn keyword mfDef          openit penrazor pensquare penstroke pickup
  syn keyword mfDef          proofoffset proofrule range reflectedabout
  syn keyword mfDef          rotatedaround screenchars screenrule screenstrokes
  syn keyword mfDef          shipit showit smode stop superellipse takepower
  syn keyword mfDef          tracingall tracingnone undraw undrawdot unfill
  syn keyword mfDef          unfilldraw upto z
  syn match   mfDef          "???"
  syn keyword mfVardef       bot byte ceiling counterclockwise cutoff decr dir
  syn keyword mfVardef       direction directionpoint grayfont hround incr
  syn keyword mfVardef       interpath inverse labelfont labels lft magstep
  " Note: nodot is not a vardef, it is used as in makelabel.lft.nodot("5",z5)
  " (METAFONT only)
  syn keyword mfVardef       makelabel max min nodot penlabels penpos
  syn keyword mfVardef       proofrulethickness round rt savepen slantfont solve
  syn keyword mfVardef       tensepath titlefont top unitvector vround whatever
  syn match   mpVardef       "\<good\.\%(x\|y\|lft\|rt\|top\|bot\)\>"
  syn keyword mfPrimaryDef   div dotprod gobbled mod
  syn keyword mfSecondaryDef intersectionpoint
  syn keyword mfTertiaryDef  softjoin thru
  syn keyword mfNewInternal  blacker currentwindow displaying eps epsilon
  syn keyword mfNewInternal  infinity join_radius number_of_modes o_correction
  syn keyword mfNewInternal  pen_bot pen_lft pen_rt pen_top pixels_per_inch
  syn keyword mfNewInternal  screen_cols screen_rows tolerance
  " Predefined constants
  syn keyword mfConstant     base_name base_version blankpicture ditto down
  syn keyword mfConstant     fullcircle halfcircle identity left lowres origin
  syn keyword mfConstant     penspeck proof quartercircle right rulepen smoke
  syn keyword mfConstant     unitpixel unitsquare up
  " Other predefined variables
  syn keyword mfVariable     aspect_ratio currentpen extra_beginchar
  syn keyword mfVariable     extra_endchar currentpen_path currentpicture
  syn keyword mfVariable     currenttransform d extra_setup h localfont mag mode
  syn keyword mfVariable     mode_name w
  " let statements:
  syn keyword mfnumExp       abs
  syn keyword mfPairExp      rotatedabout
  syn keyword mfCommand      bye relax
endif

" By default, METAFONT loads modes.mf, too
if get(g:, "plain_mf_modes", 1)
  syn keyword mfConstant     APSSixMed AgfaFourZeroZero AgfaThreeFourZeroZero
  syn keyword mfConstant     AtariNineFive AtariNineSix AtariSLMEightZeroFour
  syn keyword mfConstant     AtariSMOneTwoFour CItohEightFiveOneZero
  syn keyword mfConstant     CItohThreeOneZero CanonBJCSixZeroZero CanonCX
  syn keyword mfConstant     CanonEX CanonLBPLX CanonLBPTen CanonSX ChelgraphIBX
  syn keyword mfConstant     CompugraphicEightSixZeroZero
  syn keyword mfConstant     CompugraphicNineSixZeroZero DD DEClarge DECsmall
  syn keyword mfConstant     DataDiscNew EightThree EpsonAction
  syn keyword mfConstant     EpsonLQFiveZeroZeroLo EpsonLQFiveZeroZeroMed
  syn keyword mfConstant     EpsonMXFX EpsonSQEightSevenZero EpsonStylusPro
  syn keyword mfConstant     EpsonStylusProHigh EpsonStylusProLow
  syn keyword mfConstant     EpsonStylusProMed FourFour GThreefax HPDeskJet
  syn keyword mfConstant     HPLaserJetIIISi IBMFourTwoFiveZero IBMFourTwoOneSix
  syn keyword mfConstant     IBMFourTwoThreeZero IBMFourZeroOneNine
  syn keyword mfConstant     IBMFourZeroThreeNine IBMFourZeroTwoNine
  syn keyword mfConstant     IBMProPrinter IBMSixOneFiveFour IBMSixSixSevenZero
  syn keyword mfConstant     IBMThreeEightOneTwo IBMThreeEightTwoZero
  syn keyword mfConstant     IBMThreeOneNineThree IBMThreeOneSevenNine
  syn keyword mfConstant     IBMUlfHolleberg LASevenFive LNOthreR LNOthree
  syn keyword mfConstant     LNZeroOne LNZeroThree LPSFourZero LPSTwoZero
  syn keyword mfConstant     LexmarkFourZeroThreeNine LexmarkOptraR
  syn keyword mfConstant     LexmarkOptraS LinotypeLThreeThreeZero
  syn keyword mfConstant     LinotypeOneZeroZero LinotypeOneZeroZeroLo
  syn keyword mfConstant     LinotypeThreeZeroZeroHi MacTrueSize NeXTprinter
  syn keyword mfConstant     NeXTscreen NecTwoZeroOne Newgen NineOne
  syn keyword mfConstant     OCESixSevenFiveZeroPS OneTwoZero OneZeroZero
  syn keyword mfConstant     PrintwareSevenTwoZeroIQ Prism QMSOneSevenTwoFive
  syn keyword mfConstant     QMSOneSevenZeroZero QMSTwoFourTwoFive RicohA
  syn keyword mfConstant     RicohFortyEighty RicohFourZeroEightZero RicohLP
  syn keyword mfConstant     SparcPrinter StarNLOneZero VAXstation VTSix
  syn keyword mfConstant     VarityperFiveZeroSixZeroW
  syn keyword mfConstant     VarityperFourThreeZeroZeroHi
  syn keyword mfConstant     VarityperFourThreeZeroZeroLo
  syn keyword mfConstant     VarityperFourTwoZeroZero VarityperSixZeroZero
  syn keyword mfConstant     XeroxDocutech XeroxEightSevenNineZero
  syn keyword mfConstant     XeroxFourZeroFiveZero XeroxNineSevenZeroZero
  syn keyword mfConstant     XeroxPhaserSixTwoZeroZeroDP XeroxThreeSevenZeroZero
  syn keyword mfConstant     Xerox_world agfafzz agfatfzz amiga aps apssixhi
  syn keyword mfConstant     aselect atariezf atarinf atarins atariotf bitgraph
  syn keyword mfConstant     bjtenex bjtzzex bjtzzl bjtzzs boise canonbjc
  syn keyword mfConstant     canonex canonlbp cg cgl cgnszz citohtoz corona crs
  syn keyword mfConstant     cthreeten cx datadisc declarge decsmall deskjet
  syn keyword mfConstant     docutech dover dp dpdfezzz eighthre elvira epscszz
  syn keyword mfConstant     epsdraft epsdrft epsdrftl epsfast epsfastl epshi
  syn keyword mfConstant     epslo epsmed epsmedl epson epsonact epsonfx epsonl
  syn keyword mfConstant     epsonlo epsonlol epsonlq epsonsq epstylus epstylwr
  syn keyword mfConstant     epstyplo epstypmd epstypml epstypro epswlo epswlol
  syn keyword mfConstant     esphi fourfour gpx gtfax gtfaxhi gtfaxl gtfaxlo
  syn keyword mfConstant     gtfaxlol help hifax highfax hplaser hprugged ibm_a
  syn keyword mfConstant     ibmd ibmega ibmegal ibmfzon ibmfztn ibmpp ibmppl
  syn keyword mfConstant     ibmsoff ibmteot ibmtetz ibmtont ibmtosn ibmtosnl
  syn keyword mfConstant     ibmvga ibx imagen imagewriter itoh itohl itohtoz
  syn keyword mfConstant     itohtozl iw jetiiisi kyocera laserjet laserjetfive
  syn keyword mfConstant     laserjetfivemp laserjetfour laserjetfourthousand
  syn keyword mfConstant     laserjetfourzerozerozero laserjethi laserjetlo
  syn keyword mfConstant     laserjettwoonezerozero
  syn keyword mfConstant     laserjettwoonezerozerofastres lasermaster
  syn keyword mfConstant     laserwriter lasf lexmarkr lexmarks lexmarku
  syn keyword mfConstant     linohalf linohi linolo linolttz linoone linosuper
  syn keyword mfConstant     linothree linothreelo linotzzh ljfive ljfivemp
  syn keyword mfConstant     ljfour ljfzzz ljfzzzfr ljlo ljtozz ljtozzfr lmaster
  syn keyword mfConstant     lnotr lnzo lps lpstz lqhires lqlores lqmed lqmedl
  syn keyword mfConstant     lqmedres lview lviewl lwpro macmag mactrue modes_mf
  syn keyword mfConstant     ncd nec nechi neclm nectzo newdd newddl nexthi
  syn keyword mfConstant     nextscreen nextscrn nineone nullmode ocessfz
  syn keyword mfConstant     okidata okidatal okifourten okifte okihi onetz
  syn keyword mfConstant     onezz pcprevw pcscreen phaser phaserfs phasertf
  syn keyword mfConstant     phasertfl phasertl pixpt printware prntware
  syn keyword mfConstant     proprinter qms qmsesz qmsostf qmsoszz qmstftf ricoh
  syn keyword mfConstant     ricoha ricohlp ricohsp sherpa sparcptr starnlt
  syn keyword mfConstant     starnltl styletwo stylewr stylewri stylewriter sun
  syn keyword mfConstant     supre swtwo toshiba ultre varityper vs vtftzz
  syn keyword mfConstant     vtftzzhi vtftzzlo vtfzszw vtszz xpstzz xpstzzl
  syn keyword mfConstant     xrxesnz xrxfzfz xrxnszz xrxtszz
  syn keyword mfDef          BCPL_string coding_scheme font_face_byte
  syn keyword mfDef          font_family landscape
  syn keyword mfDef          mode_extra_info mode_help mode_param
  syn keyword mfNewInternal  blacker_min
endif

" Some other basic macro names, e.g., from cmbase, logo, etc.
if get(g:, "other_mf_macros", 1)
  syn keyword mfDef          beginlogochar
  syn keyword mfDef          font_setup
  syn keyword mfPrimitive    generate
endif

" Numeric tokens
syn match     mfNumeric      "[-]\=\d\+"
syn match     mfNumeric      "[-]\=\.\d\+"
syn match     mfNumeric      "[-]\=\d\+\.\d\+"

" METAFONT lengths
syn match     mfLength       "\<\(bp\|cc\|cm\|dd\|in\|mm\|pc\|pt\)\>"
syn match     mfLength       "[-]\=\d\+\(bp\|cc\|cm\|dd\|in\|mm\|pc\|pt\)\#\="
syn match     mfLength       "[-]\=\.\d\+\(bp\|cc\|cm\|dd\|in\|mm\|pc\|pt\)\#\="
syn match     mfLength       "[-]\=\d\+\.\d\+\(bp\|cc\|cm\|dd\|in\|mm\|pc\|pt\)\#\="

" String constants
syn match     mfOpenString   /"[^"]*/
syn region    mfString       oneline keepend start=+"+ end=+"+

" Comments:
syn keyword   mfTodoComment  contained TODO FIXME XXX DEBUG NOTE
syn match     mfComment      "%.*$" contains=mfTodoComment,@Spell

" synchronizing
syn sync maxlines=50

" Define the default highlighting
hi def link mfBoolExp      Statement
hi def link mfNumExp       Statement
hi def link mfPairExp      Statement
hi def link mfPathExp      Statement
hi def link mfPenExp       Statement
hi def link mfPicExp       Statement
hi def link mfStringExp    Statement
hi def link mfInternal     Identifier
hi def link mfCommand      Statement
hi def link mfType         Type
hi def link mfStatement    Statement
hi def link mfDefinition   Statement
hi def link mfCondition    Conditional
hi def link mfPrimitive    Statement
hi def link mfDef          Function
hi def link mfVardef       mfDef
hi def link mfPrimaryDef   mfDef
hi def link mfSecondaryDef mfDef
hi def link mfTertiaryDef  mfDef
hi def link mfCoord        Identifier
hi def link mfPoint        Identifier
hi def link mfNumeric      Number
hi def link mfLength       Number
hi def link mfComment      Comment
hi def link mfString       String
hi def link mfOpenString   Todo
hi def link mfSuffixParam  Label
hi def link mfNewInternal  mfInternal
hi def link mfVariable     Identifier
hi def link mfConstant     Constant
hi def link mfTodoComment  Todo

let b:current_syntax = "mf"

" vim:sw=2
