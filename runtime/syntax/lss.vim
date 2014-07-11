" Vim syntax file
" Language:	Lynx 2.7.1 style file
" Maintainer:	Scott Bigham <dsb@killerbunnies.org>
" Last Change:	2004 Oct 06

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" This setup is probably atypical for a syntax highlighting file, because
" most of it is not really intended to be overrideable.  Instead, the
" highlighting is supposed to correspond to the highlighting specified by
" the .lss file entries themselves; ie. the "bold" keyword should be bold,
" the "red" keyword should be red, and so forth.  The exceptions to this
" are comments, of course, and the initial keyword identifying the affected
" element, which will inherit the usual Identifier highlighting.

syn match lssElement "^[^:]\+" nextgroup=lssMono

syn match lssMono ":[^:]\+" contained nextgroup=lssFgColor contains=lssReverse,lssUnderline,lssBold,lssStandout

syn keyword	lssBold		bold		contained
syn keyword	lssReverse	reverse		contained
syn keyword	lssUnderline	underline	contained
syn keyword	lssStandout	standout	contained

syn match lssFgColor ":[^:]\+" contained nextgroup=lssBgColor contains=lssRedFg,lssBlueFg,lssGreenFg,lssBrownFg,lssMagentaFg,lssCyanFg,lssLightgrayFg,lssGrayFg,lssBrightredFg,lssBrightgreenFg,lssYellowFg,lssBrightblueFg,lssBrightmagentaFg,lssBrightcyanFg

syn case ignore
syn keyword	lssRedFg		red		contained
syn keyword	lssBlueFg		blue		contained
syn keyword	lssGreenFg		green		contained
syn keyword	lssBrownFg		brown		contained
syn keyword	lssMagentaFg		magenta		contained
syn keyword	lssCyanFg		cyan		contained
syn keyword	lssLightgrayFg		lightgray	contained
syn keyword	lssGrayFg		gray		contained
syn keyword	lssBrightredFg		brightred	contained
syn keyword	lssBrightgreenFg	brightgreen	contained
syn keyword	lssYellowFg		yellow		contained
syn keyword	lssBrightblueFg		brightblue	contained
syn keyword	lssBrightmagentaFg	brightmagenta	contained
syn keyword	lssBrightcyanFg		brightcyan	contained
syn case match

syn match lssBgColor ":[^:]\+" contained contains=lssRedBg,lssBlueBg,lssGreenBg,lssBrownBg,lssMagentaBg,lssCyanBg,lssLightgrayBg,lssGrayBg,lssBrightredBg,lssBrightgreenBg,lssYellowBg,lssBrightblueBg,lssBrightmagentaBg,lssBrightcyanBg,lssWhiteBg

syn case ignore
syn keyword	lssRedBg		red		contained
syn keyword	lssBlueBg		blue		contained
syn keyword	lssGreenBg		green		contained
syn keyword	lssBrownBg		brown		contained
syn keyword	lssMagentaBg		magenta		contained
syn keyword	lssCyanBg		cyan		contained
syn keyword	lssLightgrayBg		lightgray	contained
syn keyword	lssGrayBg		gray		contained
syn keyword	lssBrightredBg		brightred	contained
syn keyword	lssBrightgreenBg	brightgreen	contained
syn keyword	lssYellowBg		yellow		contained
syn keyword	lssBrightblueBg		brightblue	contained
syn keyword	lssBrightmagentaBg	brightmagenta	contained
syn keyword	lssBrightcyanBg		brightcyan	contained
syn keyword	lssWhiteBg		white		contained
syn case match

syn match lssComment "#.*$"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_lss_syntax_inits")
  if version < 508
    let did_lss_syntax_inits = 1
  endif

  hi def link lssComment Comment
  hi def link lssElement Identifier

  hi def lssBold		term=bold cterm=bold
  hi def lssReverse		term=reverse cterm=reverse
  hi def lssUnderline		term=underline cterm=underline
  hi def lssStandout		term=standout cterm=standout

  hi def lssRedFg		ctermfg=red
  hi def lssBlueFg		ctermfg=blue
  hi def lssGreenFg		ctermfg=green
  hi def lssBrownFg		ctermfg=brown
  hi def lssMagentaFg		ctermfg=magenta
  hi def lssCyanFg		ctermfg=cyan
  hi def lssGrayFg		ctermfg=gray
  if $COLORTERM == "rxvt"
    " On rxvt's, bright colors are activated by setting the bold attribute.
    hi def lssLightgrayFg	ctermfg=gray cterm=bold
    hi def lssBrightredFg	ctermfg=red cterm=bold
    hi def lssBrightgreenFg	ctermfg=green cterm=bold
    hi def lssYellowFg		ctermfg=yellow cterm=bold
    hi def lssBrightblueFg	ctermfg=blue cterm=bold
    hi def lssBrightmagentaFg	ctermfg=magenta cterm=bold
    hi def lssBrightcyanFg	ctermfg=cyan cterm=bold
  else
    hi def lssLightgrayFg	ctermfg=lightgray
    hi def lssBrightredFg	ctermfg=lightred
    hi def lssBrightgreenFg	ctermfg=lightgreen
    hi def lssYellowFg		ctermfg=yellow
    hi def lssBrightblueFg	ctermfg=lightblue
    hi def lssBrightmagentaFg	ctermfg=lightmagenta
    hi def lssBrightcyanFg	ctermfg=lightcyan
  endif

  hi def lssRedBg		ctermbg=red
  hi def lssBlueBg		ctermbg=blue
  hi def lssGreenBg		ctermbg=green
  hi def lssBrownBg		ctermbg=brown
  hi def lssMagentaBg		ctermbg=magenta
  hi def lssCyanBg		ctermbg=cyan
  hi def lssLightgrayBg		ctermbg=lightgray
  hi def lssGrayBg		ctermbg=gray
  hi def lssBrightredBg		ctermbg=lightred
  hi def lssBrightgreenBg	ctermbg=lightgreen
  hi def lssYellowBg		ctermbg=yellow
  hi def lssBrightblueBg	ctermbg=lightblue
  hi def lssBrightmagentaBg	ctermbg=lightmagenta
  hi def lssBrightcyanBg	ctermbg=lightcyan
  hi def lssWhiteBg		ctermbg=white ctermfg=black
endif

let b:current_syntax = "lss"

" vim: ts=8
