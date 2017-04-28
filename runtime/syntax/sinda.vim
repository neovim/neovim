" Vim syntax file
" Language:     sinda85, sinda/fluint input file
" Maintainer:   Adrian Nagle, anagle@ball.com
" Last Change:  2003 May 11
" Filenames:    *.sin
" URL:		http://www.naglenet.org/vim/syntax/sinda.vim
" MAIN URL:     http://www.naglenet.org/vim/



" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif



" Ignore case
syn case ignore



"
"
" Begin syntax definitions for sinda input and output files.
"

" Force free-form fortran format
let fortran_free_source=1

" Load FORTRAN syntax file
runtime! syntax/fortran.vim
unlet b:current_syntax



" Define keywords for SINDA
syn keyword sindaMacro    BUILD BUILDF DEBON DEBOFF DEFMOD FSTART FSTOP

syn keyword sindaOptions  TITLE PPSAVE RSI RSO OUTPUT SAVE QMAP USER1 USER2
syn keyword sindaOptions  MODEL PPOUT NOLIST MLINE NODEBUG DIRECTORIES
syn keyword sindaOptions  DOUBLEPR

syn keyword sindaRoutine  FORWRD FWDBCK STDSTL FASTIC

syn keyword sindaControl  ABSZRO ACCELX ACCELY ACCELZ ARLXCA ATMPCA
syn keyword sindaControl  BACKUP CSGFAC DRLXCA DTIMEH DTIMEI DTIMEL
syn keyword sindaControl  DTIMES DTMPCA EBALNA EBALSA EXTLIM ITEROT
syn keyword sindaControl  ITERXT ITHOLD NLOOPS NLOOPT OUTPUT OPEITR
syn keyword sindaControl  PATMOS SIGMA TIMEO TIMEND UID

syn keyword sindaSubRoutine  ASKERS ADARIN ADDARY ADDMOD ARINDV
syn keyword sindaSubRoutine  RYINV ARYMPY ARYSUB ARYTRN BAROC
syn keyword sindaSubRoutine  BELACC BNDDRV BNDGET CHENNB CHGFLD
syn keyword sindaSubRoutine  CHGLMP CHGSUC CHGVOL CHKCHL CHKCHP
syn keyword sindaSubRoutine  CNSTAB COMBAL COMPLQ COMPRS CONTRN
syn keyword sindaSubRoutine  CPRINT CRASH CRVINT CRYTRN CSIFLX
syn keyword sindaSubRoutine  CVTEMP D11CYL C11DAI D11DIM D11MCY
syn keyword sindaSubRoutine  D11MDA D11MDI D11MDT D12CYL D12MCY
syn keyword sindaSubRoutine  D12MDA D1D1DA D1D1IM D1D1WM D1D2DA
syn keyword sindaSubRoutine  D1D2WM D1DEG1 D1DEG2 D1DG1I D1IMD1
syn keyword sindaSubRoutine  D1IMIM D1IMWM D1M1DA D1M2MD D1M2WM
syn keyword sindaSubRoutine  D1MDG1 D1MDG2 D2D1WM D1DEG1 D2DEG2
syn keyword sindaSubRoutine  D2D2

syn keyword sindaIdentifier  BIV CAL DIM DIV DPM DPV DTV GEN PER PIV PIM
syn keyword sindaIdentifier  SIM SIV SPM SPV TVS TVD



" Define matches for SINDA
syn match  sindaFortran     "^F[0-9 ]"me=e-1
syn match  sindaMotran      "^M[0-9 ]"me=e-1

syn match  sindaComment     "^C.*$"
syn match  sindaComment     "^R.*$"
syn match  sindaComment     "\$.*$"

syn match  sindaHeader      "^header[^,]*"

syn match  sindaIncludeFile "include \+[^ ]\+"hs=s+8 contains=fortranInclude

syn match  sindaMacro       "^PSTART"
syn match  sindaMacro       "^PSTOP"
syn match  sindaMacro       "^FAC"

syn match  sindaInteger     "-\=\<[0-9]*\>"
syn match  sindaFloat       "-\=\<[0-9]*\.[0-9]*"
syn match  sindaScientific  "-\=\<[0-9]*\.[0-9]*E[-+]\=[0-9]\+\>"

syn match  sindaEndData		 "^END OF DATA"

if exists("thermal_todo")
  execute 'syn match  sindaTodo ' . '"^'.thermal_todo.'.*$"'
else
  syn match  sindaTodo     "^?.*$"
endif



" Define the default highlighting
" Only when an item doesn't have highlighting yet

hi def link sindaMacro		Macro
hi def link sindaOptions		Special
hi def link sindaRoutine		Type
hi def link sindaControl		Special
hi def link sindaSubRoutine	Function
hi def link sindaIdentifier	Identifier

hi def link sindaFortran		PreProc
hi def link sindaMotran		PreProc

hi def link sindaComment		Comment
hi def link sindaHeader		Typedef
hi def link sindaIncludeFile	Type
hi def link sindaInteger		Number
hi def link sindaFloat		Float
hi def link sindaScientific	Float

hi def link sindaEndData		Macro

hi def link sindaTodo		Todo



let b:current_syntax = "sinda"

" vim: ts=8 sw=2
