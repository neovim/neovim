" Vim syntax file
" Language:		Haskell with literate comments, Bird style,
"			TeX style and plain text surrounding
"			\begin{code} \end{code} blocks
" Maintainer:		Haskell Cafe mailinglist <haskell-cafe@haskell.org>
" Original Author:	Arthur van Leeuwen <arthurvl@cs.uu.nl>
" Last Change:		2010 Apr 11
" Version:		1.04
"
" Thanks to Ian Lynagh for thoughtful comments on initial versions and
" for the inspiration for writing this in the first place.
"
" This style guesses as to the type of markup used in a literate haskell
" file and will highlight (La)TeX markup if it finds any
" This behaviour can be overridden, both glabally and locally using
" the lhs_markup variable or b:lhs_markup variable respectively.
"
" lhs_markup	    must be set to either  tex	or  none  to indicate that
"		    you always want (La)TeX highlighting or no highlighting
"		    must not be set to let the highlighting be guessed
" b:lhs_markup	    must be set to eiterh  tex	or  none  to indicate that
"		    you want (La)TeX highlighting or no highlighting for
"		    this particular buffer
"		    must not be set to let the highlighting be guessed
"
"
" 2004 February 18: New version, based on Ian Lynagh's TeX guessing
"		    lhaskell.vim, cweb.vim, tex.vim, sh.vim and fortran.vim
" 2004 February 20: Cleaned up the guessing and overriding a bit
" 2004 February 23: Cleaned up syntax highlighting for \begin{code} and
"		    \end{code}, added some clarification to the attributions
" 2008 July 1:      Removed % from guess list, as it totally breaks plain
"                   text markup guessing
" 2009 April 29:    Fixed highlighting breakage in TeX mode, 
"                   thanks to Kalman Noel
"


" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" First off, see if we can inherit a user preference for lhs_markup
if !exists("b:lhs_markup")
    if exists("lhs_markup")
	if lhs_markup =~ '\<\%(tex\|none\)\>'
	    let b:lhs_markup = matchstr(lhs_markup,'\<\%(tex\|none\)\>')
	else
	    echohl WarningMsg | echo "Unknown value of lhs_markup" | echohl None
	    let b:lhs_markup = "unknown"
	endif
    else
	let b:lhs_markup = "unknown"
    endif
else
    if b:lhs_markup !~ '\<\%(tex\|none\)\>'
	let b:lhs_markup = "unknown"
    endif
endif

" Remember where the cursor is, and go to upperleft
let s:oldline=line(".")
let s:oldcolumn=col(".")
call cursor(1,1)

" If no user preference, scan buffer for our guess of the markup to
" highlight. We only differentiate between TeX and plain markup, where
" plain is not highlighted. The heuristic for finding TeX markup is if
" one of the following occurs anywhere in the file:
"   - \documentclass
"   - \begin{env}       (for env != code)
"   - \part, \chapter, \section, \subsection, \subsubsection, etc
if b:lhs_markup == "unknown"
    if search('\\documentclass\|\\begin{\(code}\)\@!\|\\\(sub\)*section\|\\chapter|\\part','W') != 0
	let b:lhs_markup = "tex"
    else
	let b:lhs_markup = "plain"
    endif
endif

" If user wants us to highlight TeX syntax or guess thinks it's TeX, read it.
if b:lhs_markup == "tex"
    runtime! syntax/tex.vim
    unlet b:current_syntax
    " Tex.vim removes "_" from 'iskeyword', but we need it for Haskell.
    setlocal isk+=_
    syntax cluster lhsTeXContainer contains=tex.*Zone,texAbstract
else
    syntax cluster lhsTeXContainer contains=.*
endif

" Literate Haskell is Haskell in between text, so at least read Haskell
" highlighting
syntax include @haskellTop syntax/haskell.vim

syntax region lhsHaskellBirdTrack start="^>" end="\%(^[^>]\)\@=" contains=@haskellTop,lhsBirdTrack containedin=@lhsTeXContainer
syntax region lhsHaskellBeginEndBlock start="^\\begin{code}\s*$" matchgroup=NONE end="\%(^\\end{code}.*$\)\@=" contains=@haskellTop,beginCodeBegin containedin=@lhsTeXContainer

syntax match lhsBirdTrack "^>" contained

syntax match beginCodeBegin "^\\begin" nextgroup=beginCodeCode contained
syntax region beginCodeCode  matchgroup=texDelimiter start="{" end="}"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link lhsBirdTrack Comment

hi def link beginCodeBegin	      texCmdName
hi def link beginCodeCode	      texSection


" Restore cursor to original position, as it may have been disturbed
" by the searches in our guessing code
call cursor (s:oldline, s:oldcolumn)

unlet s:oldline
unlet s:oldcolumn

let b:current_syntax = "lhaskell"

" vim: ts=8
