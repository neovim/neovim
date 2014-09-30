" Vim syntax file
" Language: NASTRAN input/DMAP
" Maintainer: Tom Kowalski <trk@schaefferas.com>
" Last change: April 27, 2001
"  Thanks to the authors and maintainers of fortran.vim.
"		Since DMAP shares some traits with fortran, this syntax file
"		is based on the fortran.vim syntax file.
"----------------------------------------------------------------------
" Remove any old syntax stuff hanging around
"syn clear
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif
" DMAP is not case dependent
syn case ignore
"
"--------------------DMAP SYNTAX---------------------------------------
"
" -------Executive Modules and Statements
"
syn keyword nastranDmapexecmod	       call dbview delete end equiv equivx exit
syn keyword nastranDmapexecmod	       file message purge purgex return subdmap
syn keyword nastranDmapType	       type
syn keyword nastranDmapLabel  go to goto
syn keyword nastranDmapRepeat  if else elseif endif then
syn keyword nastranDmapRepeat  do while
syn region nastranDmapString  start=+"+ end=+"+ oneline
syn region nastranDmapString  start=+'+ end=+'+ oneline
" If you don't like initial tabs in dmap (or at all)
"syn match nastranDmapIniTab  "^\t.*$"
"syn match nastranDmapTab   "\t"

" Any integer
syn match nastranDmapNumber  "-\=\<[0-9]\+\>"
" floating point number, with dot, optional exponent
syn match nastranDmapFloat  "\<[0-9]\+\.[0-9]*\([edED][-+]\=[0-9]\+\)\=\>"
" floating point number, starting with a dot, optional exponent
syn match nastranDmapFloat  "\.[0-9]\+\([edED][-+]\=[0-9]\+\)\=\>"
" floating point number, without dot, with exponent
syn match nastranDmapFloat  "\<[0-9]\+[edED][-+]\=[0-9]\+\>"

syn match nastranDmapLogical "\(true\|false\)"

syn match nastranDmapPreCondit  "^#define\>"
syn match nastranDmapPreCondit  "^#include\>"
"
" -------Comments may be contained in another line.
"
syn match nastranDmapComment "^[\$].*$"
syn match nastranDmapComment "\$.*$"
syn match nastranDmapComment "^[\$].*$" contained
syn match nastranDmapComment "\$.*$"  contained
" Treat all past 72nd column as a comment. Do not work with tabs!
" Breaks down when 72-73rd column is in another match (eg number or keyword)
syn match  nastranDmapComment  "^.\{-72}.*$"lc=72 contained

"
" -------Utility Modules
"
syn keyword nastranDmapUtilmod	       append copy dbc dbdict dbdir dmin drms1
syn keyword nastranDmapUtilmod	       dtiin eltprt ifp ifp1 inputt2 inputt4 lamx
syn keyword nastranDmapUtilmod	       matgen matgpr matmod matpch matprn matprt
syn keyword nastranDmapUtilmod	       modtrl mtrxin ofp output2 output4 param
syn keyword nastranDmapUtilmod	       paraml paramr prtparam pvt scalar
syn keyword nastranDmapUtilmod	       seqp setval tabedit tabprt tabpt vec vecplot
syn keyword nastranDmapUtilmod	       xsort
"
" -------Matrix Modules
"
syn keyword nastranDmapMatmod	       add add5 cead dcmp decomp diagonal fbs merge
syn keyword nastranDmapMatmod	       mpyad norm read reigl smpyad solve solvit
syn keyword nastranDmapMatmod	       trnsp umerge umerge1 upartn dmiin partn
syn region  nastranDmapMatmod	       start=+^ *[Dd][Mm][Ii]+ end=+[\/]+
"
" -------Implicit Functions
"
syn keyword nastranDmapImplicit abs acos acosh andl asin asinh atan atan2
syn keyword nastranDmapImplicit atanh atanh2 char clen clock cmplx concat1
syn keyword nastranDmapImplicit concat2 concat3 conjg cos cosh dble diagoff
syn keyword nastranDmapImplicit diagon dim dlablank dlxblank dprod eqvl exp
syn keyword nastranDmapImplicit getdiag getsys ichar imag impl index indexstr
syn keyword nastranDmapImplicit int itol leq lge lgt lle llt lne log log10
syn keyword nastranDmapImplicit logx ltoi mcgetsys mcputsys max min mod neqvl
syn keyword nastranDmapImplicit nint noop normal notl numeq numge numgt numle
syn keyword nastranDmapImplicit numlt numne orl pi precison putdiag putsys
syn keyword nastranDmapImplicit rand rdiagon real rtimtogo setcore sign sin
syn keyword nastranDmapImplicit sinh sngl sprod sqrt substrin tan tanh
syn keyword nastranDmapImplicit timetogo wlen xorl
"
"
"--------------------INPUT FILE SYNTAX---------------------------------------
"
"
" -------Nastran Statement
"
syn keyword nastranNastranCard		 nastran
"
" -------The File Management Section (FMS)
"
syn region nastranFMSCard start=+^ *[Aa][Cc][Qq][Uu][Ii]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Aa][Ss][Ss][Ii][Gg]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Cc][oO][Nn][Nn][Ee]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Dd][Bb][Cc][Ll][Ee]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Dd][Bb][Dd][Ii][Cc]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Dd][Bb][Dd][Ii][Rr]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Dd][Bb][Ff][Ii][Xx]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Dd][Bb][Ll][Oo][Aa]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Dd][Bb][Ll][Oo][Cc]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Dd][Bb][Ss][Ee][Tt]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Dd][Bb][Uu][Nn][Ll]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Dd][Bb][Uu][Pp][Dd]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Dd][Ee][Ff][Ii][Nn]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Ee][Nn][Dd][Jj][Oo]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Ee][Xx][Pp][Aa][Nn]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Ii][Nn][Cc][Ll][Uu]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Ii][Nn][Ii][Tt]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Pp][Rr][Oo][Jj]+ end=+$+  oneline
syn region nastranFMSCard start=+^ *[Rr][Ee][Ss][Tt]+ end=+$+  oneline
syn match   nastranDmapUtilmod	   "^ *[Rr][Ee][Ss][Tt][Aa].*,.*," contains=nastranDmapComment
"
" -------Executive Control Section
"
syn region nastranECSCard start=+^ *[Aa][Ll][Tt][Ee][Rr]+ end=+$+  oneline
syn region nastranECSCard start=+^ *[Aa][Pp][Pp]+ end=+$+  oneline
syn region nastranECSCard start=+^ *[Cc][Oo][Mm][Pp][Ii]+ end=+$+  oneline
syn region nastranECSCard start=+^ *[Dd][Ii][Aa][Gg] + end=+$+  oneline
syn region nastranECSCard start=+^ *[Ee][Cc][Hh][Oo]+ end=+$+  oneline
syn region nastranECSCard start=+^ *[Ee][Nn][Dd][Aa][Ll]+ end=+$+  oneline
syn region nastranECSCard start=+^ *[Ii][Dd]+ end=+$+  oneline
syn region nastranECSCard start=+^ *[Ii][Nn][Cc][Ll][Uu]+ end=+$+  oneline
syn region nastranECSCard start=+^ *[Ll][Ii][Nn][Kk]+ end=+$+  oneline
syn region nastranECSCard start=+^ *[Mm][Aa][Ll][Tt][Ee]+ end=+$+  oneline
syn region nastranECSCard start=+^ *[Ss][Oo][Ll] + end=+$+  oneline
syn region nastranECSCard start=+^ *[Tt][Ii][Mm][Ee]+ end=+$+  oneline
"
" -------Delimiters
"
syn match nastranDelimiter "[Cc][Ee][Nn][Dd]" contained
syn match nastranDelimiter "[Bb][Ee][Gg][Ii][Nn]" contained
syn match nastranDelimiter " *[Bb][Uu][Ll][Kk]" contained
syn match nastranDelimiter "[Ee][Nn][Dd] *[dD][Aa][Tt][Aa]" contained
"
" -------Case Control section
"
syn region nastranCC start=+^ *[Cc][Ee][Nn][Dd]+ end=+^ *[Bb][Ee][Gg][Ii][Nn]+ contains=nastranDelimiter,nastranBulkData,nastranDmapComment

"
" -------Bulk Data section
"
syn region nastranBulkData start=+ *[Bb][Uu][Ll][Kk] *$+ end=+^ [Ee][Nn][Dd] *[Dd]+ contains=nastranDelimiter,nastranDmapComment
"
" -------The following cards may appear in multiple sections of the file
"
syn keyword nastranUtilCard ECHOON ECHOOFF INCLUDE PARAM


if version >= 508 || !exists("did_nastran_syntax_inits")
  if version < 508
     let did_nastran_syntax_inits = 1
     command -nargs=+ HiLink hi link <args>
  else
     command -nargs=+ HiLink hi link <args>
  endif
  " The default methods for highlighting.  Can be overridden later
  HiLink nastranDmapexecmod	     Statement
  HiLink nastranDmapType	     Type
  HiLink nastranDmapPreCondit	     Error
  HiLink nastranDmapUtilmod	     PreProc
  HiLink nastranDmapMatmod	     nastranDmapUtilmod
  HiLink nastranDmapString	     String
  HiLink nastranDmapNumber	     Constant
  HiLink nastranDmapFloat	     nastranDmapNumber
  HiLink nastranDmapInitTab	     nastranDmapNumber
  HiLink nastranDmapTab		     nastranDmapNumber
  HiLink nastranDmapLogical	     nastranDmapExecmod
  HiLink nastranDmapImplicit	     Identifier
  HiLink nastranDmapComment	     Comment
  HiLink nastranDmapRepeat	     nastranDmapexecmod
  HiLink nastranNastranCard	     nastranDmapPreCondit
  HiLink nastranECSCard		     nastranDmapUtilmod
  HiLink nastranFMSCard		     nastranNastranCard
  HiLink nastranCC		     nastranDmapexecmod
  HiLink nastranDelimiter	     Special
  HiLink nastranBulkData	     nastranDmapType
  HiLink nastranUtilCard	     nastranDmapexecmod
  delcommand HiLink
endif

let b:current_syntax = "nastran"

"EOF vim: ts=8 noet tw=120 sw=8 sts=0
