" Vim syntax file
" Language:     sinda85, sinda/fluint output file
" Maintainer:   Adrian Nagle, anagle@ball.com
" Last Change:  2003 May 11
" Filenames:    *.out
" URL:		http://www.naglenet.org/vim/syntax/sindaout.vim
" MAIN URL:     http://www.naglenet.org/vim/



" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif



" Ignore case
syn case match



" Load SINDA syntax file
runtime! syntax/sinda.vim
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
" Only when an item doesn't have highlighting yet
command -nargs=+ HiLink hi def link <args>

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


let b:current_syntax = "sindaout"

" vim: ts=8 sw=2
