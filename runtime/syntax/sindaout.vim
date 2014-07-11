" Vim syntax file
" Language:     sinda85, sinda/fluint output file
" Maintainer:   Adrian Nagle, anagle@ball.com
" Last Change:  2003 May 11
" Filenames:    *.out
" URL:		http://www.naglenet.org/vim/syntax/sindaout.vim
" MAIN URL:     http://www.naglenet.org/vim/



" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif



" Ignore case
syn case match



" Load SINDA syntax file
if version < 600
  source <sfile>:p:h/sinda.vim
else
  runtime! syntax/sinda.vim
endif
unlet b:current_syntax



"
"
" Begin syntax definitions for sinda output files.
"

" Define keywords for sinda output
syn case match

syn keyword sindaoutPos       ON SI
syn keyword sindaoutNeg       OFF ENG



" Define matches for sinda output
syn match sindaoutFile	       ": \w*\.TAK"hs=s+2

syn match sindaoutInteger      "T\=[0-9]*\>"ms=s+1

syn match sindaoutSectionDelim "[-<>]\{4,}" contains=sindaoutSectionTitle
syn match sindaoutSectionDelim ":\=\.\{4,}:\=" contains=sindaoutSectionTitle
syn match sindaoutSectionTitle "[-<:] \w[0-9A-Za-z_() ]\+ [->:]"hs=s+1,me=e-1

syn match sindaoutHeaderDelim  "=\{5,}"
syn match sindaoutHeaderDelim  "|\{5,}"
syn match sindaoutHeaderDelim  "+\{5,}"

syn match sindaoutLabel		"Input File:" contains=sindaoutFile
syn match sindaoutLabel		"Begin Solution: Routine"

syn match sindaoutError		"<<< Error >>>"


" Define the default highlighting
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_sindaout_syntax_inits")
  if version < 508
    let did_sindaout_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  hi sindaHeaderDelim  ctermfg=Black ctermbg=Green	       guifg=Black guibg=Green

  HiLink sindaoutPos		     Statement
  HiLink sindaoutNeg		     PreProc
  HiLink sindaoutTitle		     Type
  HiLink sindaoutFile		     sindaIncludeFile
  HiLink sindaoutInteger	     sindaInteger

  HiLink sindaoutSectionDelim	      Delimiter
  HiLink sindaoutSectionTitle	     Exception
  HiLink sindaoutHeaderDelim	     SpecialComment
  HiLink sindaoutLabel		     Identifier

  HiLink sindaoutError		     Error

  delcommand HiLink
endif


let b:current_syntax = "sindaout"

" vim: ts=8 sw=2
