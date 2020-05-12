" Vim syntax file
" Language:     TRASYS input file
" Maintainer:   Adrian Nagle, anagle@ball.com
" Last Change:  2003 May 11
" Filenames:    *.inp
" URL:		http://www.naglenet.org/vim/syntax/trasys.vim
" MAIN URL:     http://www.naglenet.org/vim/



" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif


" Force free-form fortran format
let fortran_free_source=1

" Load FORTRAN syntax file
runtime! syntax/fortran.vim
unlet b:current_syntax


" Ignore case
syn case ignore



" Define keywords for TRASYS
syn keyword trasysOptions    model rsrec info maxfl nogo dmpdoc
syn keyword trasysOptions    rsi rti rso rto bcdou cmerg emerg
syn keyword trasysOptions    user1 nnmin erplot

syn keyword trasysSurface    icsn tx ty tz rotx roty rotz inc bcsn
syn keyword trasysSurface    nnx nny nnz nnax nnr nnth unnx
syn keyword trasysSurface    unny unnz unnax unnr unnth type idupsf
syn keyword trasysSurface    imagsf act active com shade bshade axmin
syn keyword trasysSurface    axmax zmin zmax rmin rmax thmin thmin
syn keyword trasysSurface    thmax alpha emiss trani trans spri sprs
syn keyword trasysSurface    refno posit com dupbcs dimensions
syn keyword trasysSurface    dimension position prop surfn

syn keyword trasysSurfaceType rect trap disk cyl cone sphere parab
syn keyword trasysSurfaceType box5 box6 shpero tor ogiv elem tape poly

syn keyword trasysSurfaceArgs ff di top bottom in out both no only

syn keyword trasysArgs       fig smn nodea zero only ir sol
syn keyword trasysArgs       both wband stepn initl

syn keyword trasysOperations orbgen build

"syn keyword trasysSubRoutine call
syn keyword trasysSubRoutine chgblk ndata ndatas odata odatas
syn keyword trasysSubRoutine pldta ffdata cmdata adsurf rbdata
syn keyword trasysSubRoutine rtdata pffshd orbit1 orbit2 orient
syn keyword trasysSubRoutine didt1 didt1s didt2 didt2s spin
syn keyword trasysSubRoutine spinav dicomp distab drdata gbdata
syn keyword trasysSubRoutine gbaprx rkdata rcdata aqdata stfaq
syn keyword trasysSubRoutine qodata qoinit modar modpr modtr
syn keyword trasysSubRoutine modprs modshd moddat rstoff rston
syn keyword trasysSubRoutine rsmerg ffread diread ffusr1 diusr1
syn keyword trasysSubRoutine surfp didt3 didt3s romain stfrc
syn keyword trasysSubRoutine rornt rocstr romove flxdata title

syn keyword trassyPrcsrSegm  nplot oplot plot cmcal ffcal rbcal
syn keyword trassyPrcsrSegm  rtcal dical drcal sfcal gbcal rccal
syn keyword trassyPrcsrSegm  rkcal aqcal qocal



" Define matches for TRASYS
syn match  trasysOptions     "list source"
syn match  trasysOptions     "save source"
syn match  trasysOptions     "no print"

"syn match  trasysSurface     "^K *.* [^$]"
"syn match  trasysSurface     "^D *[0-9]*\.[0-9]\+"
"syn match  trasysSurface     "^I *.*[0-9]\+\.\="
"syn match  trasysSurface     "^N *[0-9]\+"
"syn match  trasysSurface     "^M *[a-z[A-Z0-9]\+"
"syn match  trasysSurface     "^B[C][S] *[a-zA-Z0-9]*"
"syn match  trasysSurface     "^S *SURFN.*[0-9]"
syn match  trasysSurface     "P[0-9]* *="he=e-1

syn match  trasysIdentifier  "^L "he=e-1
syn match  trasysIdentifier  "^K "he=e-1
syn match  trasysIdentifier  "^D "he=e-1
syn match  trasysIdentifier  "^I "he=e-1
syn match  trasysIdentifier  "^N "he=e-1
syn match  trasysIdentifier  "^M "he=e-1
syn match  trasysIdentifier  "^B[C][S]"
syn match  trasysIdentifier  "^S "he=e-1

syn match  trasysComment     "^C.*$"
syn match  trasysComment     "^R.*$"
syn match  trasysComment     "\$.*$"

syn match  trasysHeader      "^header[^,]*"

syn match  trasysMacro       "^FAC"

syn match  trasysInteger     "-\=\<[0-9]*\>"
syn match  trasysFloat       "-\=\<[0-9]*\.[0-9]*"
syn match  trasysScientific  "-\=\<[0-9]*\.[0-9]*E[-+]\=[0-9]\+\>"

syn match  trasysBlank       "' \+'"hs=s+1,he=e-1

syn match  trasysEndData     "^END OF DATA"

if exists("thermal_todo")
  execute 'syn match  trasysTodo ' . '"^'.thermal_todo.'.*$"'
else
  syn match  trasysTodo  "^?.*$"
endif



" Define regions for TRASYS
syn region trasysComment  matchgroup=trasysHeader start="^HEADER DOCUMENTATION DATA" end="^HEADER[^,]*"



" Define synchronizing patterns for TRASYS
syn sync maxlines=500
syn sync match trasysSync grouphere trasysComment "^HEADER DOCUMENTATION DATA"



" Define the default highlighting
" Only when an item doesn't have highlighting yet

hi def link trasysOptions		Special
hi def link trasysSurface		Special
hi def link trasysSurfaceType	Constant
hi def link trasysSurfaceArgs	Constant
hi def link trasysArgs		Constant
hi def link trasysOperations	Statement
hi def link trasysSubRoutine	Statement
hi def link trassyPrcsrSegm	PreProc
hi def link trasysIdentifier	Identifier
hi def link trasysComment		Comment
hi def link trasysHeader		Typedef
hi def link trasysMacro		Macro
hi def link trasysInteger		Number
hi def link trasysFloat		Float
hi def link trasysScientific	Float

hi def link trasysBlank		SpecialChar

hi def link trasysEndData		Macro

hi def link trasysTodo		Todo



let b:current_syntax = "trasys"

" vim: ts=8 sw=2
