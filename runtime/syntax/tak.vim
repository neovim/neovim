" Vim syntax file
" Language:     TAK2, TAK3, TAK2000 thermal modeling input file
" Maintainer:   Adrian Nagle, anagle@ball.com
" Last Change:  2003 May 11
" Filenames:    *.tak
" URL:		http://www.naglenet.org/vim/syntax/tak.vim
" MAIN URL:     http://www.naglenet.org/vim/



" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif



" Ignore case
syn case ignore



"
"
" Begin syntax definitions for tak input file.
"

" Force free-form fortran format
let fortran_free_source=1

" Load FORTRAN syntax file
if version < 600
  source <sfile>:p:h/fortran.vim
else
  runtime! syntax/fortran.vim
endif
unlet b:current_syntax



" Define keywords for TAK and TAKOUT
syn keyword takOptions  AUTODAMP CPRINT CSGDUMP GPRINT HPRINT LODTMP
syn keyword takOptions  LOGIC LPRINT NCVPRINT PLOTQ QPRINT QDUMP
syn keyword takOptions  SUMMARY SOLRTN UID DICTIONARIES

syn keyword takRoutine  SSITER FWDWRD FWDBCK BCKWRD

syn keyword takControl  ABSZRO BACKUP DAMP DTIMEI DTIMEL DTIMEH IFC
syn keyword takControl  MAXTEMP NLOOPS NLOOPT NODELIST OUTPUT PLOT
syn keyword takControl  SCALE SIGMA SSCRIT TIMEND TIMEN TIMEO TRCRIT
syn keyword takControl  PLOT

syn keyword takSolids   PLATE CYL
syn keyword takSolidsArg   ID MATNAM NTYPE TEMP XL YL ZL ISTRN ISTRG NNX
syn keyword takSolidsArg   NNY NNZ INCX INCY INCZ IAK IAC DIFF ARITH BOUN
syn keyword takSolidsArg   RMIN RMAX AXMAX NNR NNTHETA INCR INCTHETA END

syn case ignore

syn keyword takMacro    fac pstart pstop
syn keyword takMacro    takcommon fstart fstop

syn keyword takIdentifier  flq flx gen ncv per sim siv stf stv tvd tvs
syn keyword takIdentifier  tvt pro thm



" Define matches for TAK
syn match  takFortran     "^F[0-9 ]"me=e-1
syn match  takMotran      "^M[0-9 ]"me=e-1

syn match  takComment     "^C.*$"
syn match  takComment     "^R.*$"
syn match  takComment     "\$.*$"

syn match  takHeader      "^header[^,]*"

syn match  takIncludeFile "include \+[^ ]\+"hs=s+8 contains=fortranInclude

syn match  takInteger     "-\=\<[0-9]*\>"
syn match  takFloat       "-\=\<[0-9]*\.[0-9]*"
syn match  takScientific  "-\=\<[0-9]*\.[0-9]*E[-+]\=[0-9]\+\>"

syn match  takEndData     "END OF DATA"

if exists("thermal_todo")
  execute 'syn match  takTodo ' . '"^'.thermal_todo.'.*$"'
else
  syn match  takTodo	    "^?.*$"
endif



" Define the default highlighting
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_tak_syntax_inits")
  if version < 508
    let did_tak_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink takMacro		Macro
  HiLink takOptions		Special
  HiLink takRoutine		Type
  HiLink takControl		Special
  HiLink takSolids		Special
  HiLink takSolidsArg		Statement
  HiLink takIdentifier		Identifier

  HiLink takFortran		PreProc
  HiLink takMotran		PreProc

  HiLink takComment		Comment
  HiLink takHeader		Typedef
  HiLink takIncludeFile		Type
  HiLink takInteger		Number
  HiLink takFloat		Float
  HiLink takScientific		Float

  HiLink takEndData		Macro

  HiLink takTodo		Todo

  delcommand HiLink
endif


let b:current_syntax = "tak"

" vim: ts=8 sw=2
