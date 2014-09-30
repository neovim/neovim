" Vim syntax file
" Language:	OPL
" Maintainer:	Czo <Olivier.Sirol@lip6.fr>
" Last Change:	2012 Feb 03 by Thilo Six
" $Id: opl.vim,v 1.1 2004/06/13 17:34:11 vimboss Exp $

" Open Psion Language... (EPOC16/EPOC32)

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" case is not significant
syn case ignore

" A bunch of useful OPL keywords
syn keyword OPLStatement proc endp abs acos addr adjustalloc alert alloc app
syn keyword OPLStatement append appendsprite asc asin at atan back beep
syn keyword OPLStatement begintrans bookmark break busy byref cache
syn keyword OPLStatement cachehdr cacherec cachetidy call cancel caption
syn keyword OPLStatement changesprite chr$ clearflags close closesprite cls
syn keyword OPLStatement cmd$ committrans compact compress const continue
syn keyword OPLStatement copy cos count create createsprite cursor
syn keyword OPLStatement datetosecs datim$ day dayname$ days daystodate
syn keyword OPLStatement dbuttons dcheckbox dchoice ddate declare dedit
syn keyword OPLStatement deditmulti defaultwin deg delete dfile dfloat
syn keyword OPLStatement dialog diaminit diampos dinit dir$ dlong do dow
syn keyword OPLStatement dposition drawsprite dtext dtime dxinput edit else
syn keyword OPLStatement elseif enda endif endv endwh entersend entersend0
syn keyword OPLStatement eof erase err err$ errx$ escape eval exist exp ext
syn keyword OPLStatement external find findfield findlib first fix$ flags
syn keyword OPLStatement flt font freealloc gat gborder gbox gbutton
syn keyword OPLStatement gcircle gclock gclose gcls gcolor gcopy gcreate
syn keyword OPLStatement gcreatebit gdrawobject gellipse gen$ get get$
syn keyword OPLStatement getcmd$ getdoc$ getevent getevent32 geteventa32
syn keyword OPLStatement geteventc getlibh gfill gfont ggmode ggrey gheight
syn keyword OPLStatement gidentity ginfo ginfo32 ginvert giprint glineby
syn keyword OPLStatement glineto gloadbit gloadfont global gmove gorder
syn keyword OPLStatement goriginx goriginy goto gotomark gpatt gpeekline
syn keyword OPLStatement gpoly gprint gprintb gprintclip grank gsavebit
syn keyword OPLStatement gscroll gsetpenwidth gsetwin gstyle gtmode gtwidth
syn keyword OPLStatement gunloadfont gupdate guse gvisible gwidth gx
syn keyword OPLStatement gxborder gxprint gy hex$ hour iabs icon if include
syn keyword OPLStatement input insert int intf intrans key key$ keya keyc
syn keyword OPLStatement killmark kmod last lclose left$ len lenalloc
syn keyword OPLStatement linklib ln loadlib loadm loc local lock log lopen
syn keyword OPLStatement lower$ lprint max mcard mcasc mean menu mid$ min
syn keyword OPLStatement minit minute mkdir modify month month$ mpopup
syn keyword OPLStatement newobj newobjh next notes num$ odbinfo off onerr
syn keyword OPLStatement open openr opx os parse$ path pause peek pi
syn keyword OPLStatement pointerfilter poke pos position possprite print
syn keyword OPLStatement put rad raise randomize realloc recsize rename
syn keyword OPLStatement rept$ return right$ rmdir rnd rollback sci$ screen
syn keyword OPLStatement screeninfo second secstodate send setdoc setflags
syn keyword OPLStatement setname setpath sin space sqr statuswin
syn keyword OPLStatement statwininfo std stop style sum tan testevent trap
syn keyword OPLStatement type uadd unloadlib unloadm until update upper$
syn keyword OPLStatement use usr usr$ usub val var vector week while year
" syn keyword OPLStatement rem


syn match  OPLNumber		"\<\d\+\>"
syn match  OPLNumber		"\<\d\+\.\d*\>"
syn match  OPLNumber		"\.\d\+\>"

syn region  OPLString		start=+"+   end=+"+
syn region  OPLComment		start="REM[\t ]" end="$"
syn match   OPLMathsOperator    "-\|=\|[:<>+\*^/\\]"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_OPL_syntax_inits")
  if version < 508
    let did_OPL_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink OPLStatement		Statement
  HiLink OPLNumber		Number
  HiLink OPLString		String
  HiLink OPLComment		Comment
  HiLink OPLMathsOperator	Conditional
"  HiLink OPLError		Error

  delcommand HiLink
endif

let b:current_syntax = "opl"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8
