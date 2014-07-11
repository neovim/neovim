" Vim syntax file
" Language:     TAK2, TAK3, TAK2000 thermal modeling output file
" Maintainer:   Adrian Nagle, anagle@ball.com
" Last Change:  2003 May 11
" Filenames:    *.out
" URL:		http://www.naglenet.org/vim/syntax/takout.vim
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



" Load TAK syntax file
if version < 600
  source <sfile>:p:h/tak.vim
else
  runtime! syntax/tak.vim
endif
unlet b:current_syntax



"
"
" Begin syntax definitions for tak output files.
"

" Define keywords for TAK output
syn case match

syn keyword takoutPos       ON SI
syn keyword takoutNeg       OFF ENG



" Define matches for TAK output
syn match takoutTitle	     "TAK III"
syn match takoutTitle	     "Release \d.\d\d"
syn match takoutTitle	     " K & K  Associates *Thermal Analysis Kit III *Serial Number \d\d-\d\d\d"

syn match takoutFile	     ": \w*\.TAK"hs=s+2

syn match takoutInteger      "T\=[0-9]*\>"ms=s+1

syn match takoutSectionDelim "[-<>]\{4,}" contains=takoutSectionTitle
syn match takoutSectionDelim ":\=\.\{4,}:\=" contains=takoutSectionTitle
syn match takoutSectionTitle "[-<:] \w[0-9A-Za-z_() ]\+ [->:]"hs=s+1,me=e-1

syn match takoutHeaderDelim  "=\{5,}"
syn match takoutHeaderDelim  "|\{5,}"
syn match takoutHeaderDelim  "+\{5,}"

syn match takoutLabel	     "Input File:" contains=takoutFile
syn match takoutLabel	     "Begin Solution: Routine"

syn match takoutError	     "<<< Error >>>"


" Define the default highlighting
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_takout_syntax_inits")
  if version < 508
    let did_takout_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink takoutPos		   Statement
  HiLink takoutNeg		   PreProc
  HiLink takoutTitle		   Type
  HiLink takoutFile		   takIncludeFile
  HiLink takoutInteger		   takInteger

  HiLink takoutSectionDelim	    Delimiter
  HiLink takoutSectionTitle	   Exception
  HiLink takoutHeaderDelim	   SpecialComment
  HiLink takoutLabel		   Identifier

  HiLink takoutError		   Error

  delcommand HiLink
endif


let b:current_syntax = "takout"

" vim: ts=8 sw=2
