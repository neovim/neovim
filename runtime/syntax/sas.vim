" Vim syntax file
" Language:	SAS
" Maintainer:	James Kidd <james.kidd@covance.com>
" Last Change:  2012 Apr 20
"               Corrected bug causing some keywords to appear as strings instead
"               18 Jul 2008 by Paulo Tanimoto <ptanimoto@gmail.com>
"               Fixed comments with * taking multiple lines.
"               Fixed highlighting of macro keywords.
"               Added words to cases that didn't fit anywhere.
"             	02 Jun 2003
"		Added highlighting for additional keywords and such;
"		Attempted to match SAS default syntax colors;
"		Changed syncing so it doesn't lose colors on large blocks;
"		Much thanks to Bob Heckel for knowledgeable tweaking.
"  quit when a syntax file was already loaded
if exists("b:current_syntax")
   finish
endif

syn case ignore

syn region sasString	start=+"+  skip=+\\\\\|\\"+  end=+"+
syn region sasString	start=+'+  skip=+\\\\\|\\"+  end=+'+

" Want region from 'cards;' to ';' to be captured (Bob Heckel)
syn region sasCards	start="^\s*CARDS.*" end="^\s*;\s*$"
syn region sasCards	start="^\s*DATALINES.*" end="^\s*;\s*$"

syn match sasNumber	"-\=\<\d*\.\=[0-9_]\>"

" Block comment
syn region sasComment	start="/\*"  end="\*/" contains=sasTodo

" Ignore misleading //JCL SYNTAX... (Bob Heckel)
syn region sasComment	start="[^/][^/]/\*"  end="\*/" contains=sasTodo

" Previous code for comments was written by Bob Heckel
" Comments with * may take multiple lines (Paulo Tanimoto)
syn region sasComment start=";\s*\*"hs=s+1 end=";" contains=sasTodo

" Comments with * starting after a semicolon (Paulo Tanimoto)
syn region sasComment start="^\s*\*" end=";" contains=sasTodo

" This line defines macro variables in code.  "hi def link" at end of file
" defines the color scheme. Begin region with ampersand and end with
" any non-word character offset by -1; put ampersand in the skip list
" just in case it is used to concatenate macro variable values.

" Thanks to ronald höllwarth for this fix to an intra-versioning
" problem with this little feature

syn region sasMacroVar	start="&" skip="[_&]" end="\W"he=e-1


" I dont think specific PROCs need to be listed if use this line (Bob Heckel).
syn match sasProc		"^\s*PROC \w\+"
syn keyword sasStep		RUN QUIT DATA


" Base SAS Procs - version 8.1

syn keyword sasConditional	DO ELSE END IF THEN UNTIL WHILE

syn keyword sasStatement	ABORT ARRAY ATTRIB BY CALL CARDS CARDS4 CATNAME
syn keyword sasStatement	CONTINUE DATALINES DATALINES4 DELETE DISPLAY
syn keyword sasStatement	DM DROP ENDSAS ERROR FILE FILENAME FOOTNOTE
syn keyword sasStatement	FORMAT GOTO INFILE INFORMAT INPUT KEEP
syn keyword sasStatement	LABEL LEAVE LENGTH LIBNAME LINK LIST LOSTCARD
syn keyword sasStatement	MERGE MISSING MODIFY OPTIONS OUTPUT PAGE
syn keyword sasStatement	PUT REDIRECT REMOVE RENAME REPLACE RETAIN
syn keyword sasStatement	RETURN SELECT SET SKIP STARTSAS STOP TITLE
syn keyword sasStatement	UPDATE WAITSAS WHERE WINDOW X SYSTASK

" Keywords that are used in Proc SQL
" I left them as statements because SAS's enhanced editor highlights
" them the same as normal statements used in data steps (Jim Kidd)

syn keyword sasStatement	ADD AND ALTER AS CASCADE CHECK CREATE
syn keyword sasStatement	DELETE DESCRIBE DISTINCT DROP FOREIGN
syn keyword sasStatement	FROM GROUP HAVING INDEX INSERT INTO IN
syn keyword sasStatement	KEY LIKE MESSAGE MODIFY MSGTYPE NOT
syn keyword sasStatement	NULL ON OR ORDER PRIMARY REFERENCES
syn keyword sasStatement	RESET RESTRICT SELECT SET TABLE
syn keyword sasStatement	UNIQUE UPDATE VALIDATE VIEW WHERE

" Match declarations have to appear one per line (Paulo Tanimoto)
syn match sasStatement	"FOOTNOTE\d"
syn match sasStatement	"TITLE\d"

" Match declarations have to appear one per line (Paulo Tanimoto)
syn match sasMacro "%BQUOTE"
syn match sasMacro "%NRBQUOTE"
syn match sasMacro "%CMPRES"
syn match sasMacro "%QCMPRES"
syn match sasMacro "%COMPSTOR"
syn match sasMacro "%DATATYP"
syn match sasMacro "%DISPLAY"
syn match sasMacro "%DO"
syn match sasMacro "%ELSE"
syn match sasMacro "%END"
syn match sasMacro "%EVAL"
syn match sasMacro "%GLOBAL"
syn match sasMacro "%GOTO"
syn match sasMacro "%IF"
syn match sasMacro "%INDEX"
syn match sasMacro "%INPUT"
syn match sasMacro "%KEYDEF"
syn match sasMacro "%LABEL"
syn match sasMacro "%LEFT"
syn match sasMacro "%LENGTH"
syn match sasMacro "%LET"
syn match sasMacro "%LOCAL"
syn match sasMacro "%LOWCASE"
syn match sasMacro "%MACRO"
syn match sasMacro "%MEND"
syn match sasMacro "%NRBQUOTE"
syn match sasMacro "%NRQUOTE"
syn match sasMacro "%NRSTR"
syn match sasMacro "%PUT"
syn match sasMacro "%QCMPRES"
syn match sasMacro "%QLEFT"
syn match sasMacro "%QLOWCASE"
syn match sasMacro "%QSCAN"
syn match sasMacro "%QSUBSTR"
syn match sasMacro "%QSYSFUNC"
syn match sasMacro "%QTRIM"
syn match sasMacro "%QUOTE"
syn match sasMacro "%QUPCASE"
syn match sasMacro "%SCAN"
syn match sasMacro "%STR"
syn match sasMacro "%SUBSTR"
syn match sasMacro "%SUPERQ"
syn match sasMacro "%SYSCALL"
syn match sasMacro "%SYSEVALF"
syn match sasMacro "%SYSEXEC"
syn match sasMacro "%SYSFUNC"
syn match sasMacro "%SYSGET"
syn match sasMacro "%SYSLPUT"
syn match sasMacro "%SYSPROD"
syn match sasMacro "%SYSRC"
syn match sasMacro "%SYSRPUT"
syn match sasMacro "%THEN"
syn match sasMacro "%TO"
syn match sasMacro "%TRIM"
syn match sasMacro "%UNQUOTE"
syn match sasMacro "%UNTIL"
syn match sasMacro "%UPCASE"
syn match sasMacro "%VERIFY"
syn match sasMacro "%WHILE"
syn match sasMacro "%WINDOW"

" SAS Functions

syn keyword sasFunction	ABS ADDR AIRY ARCOS ARSIN ATAN ATTRC ATTRN
syn keyword sasFunction	BAND BETAINV BLSHIFT BNOT BOR BRSHIFT BXOR
syn keyword sasFunction	BYTE CDF CEIL CEXIST CINV CLOSE CNONCT COLLATE
syn keyword sasFunction	COMPBL COMPOUND COMPRESS COS COSH CSS CUROBS
syn keyword sasFunction	CV DACCDB DACCDBSL DACCSL DACCSYD DACCTAB
syn keyword sasFunction	DAIRY DATE DATEJUL DATEPART DATETIME DAY
syn keyword sasFunction	DCLOSE DEPDB DEPDBSL DEPDBSL DEPSL DEPSL
syn keyword sasFunction	DEPSYD DEPSYD DEPTAB DEPTAB DEQUOTE DHMS
syn keyword sasFunction	DIF DIGAMMA DIM DINFO DNUM DOPEN DOPTNAME
syn keyword sasFunction	DOPTNUM DREAD DROPNOTE DSNAME ERF ERFC EXIST
syn keyword sasFunction	EXP FAPPEND FCLOSE FCOL FDELETE FETCH FETCHOBS
syn keyword sasFunction	FEXIST FGET FILEEXIST FILENAME FILEREF FINFO
syn keyword sasFunction	FINV FIPNAME FIPNAMEL FIPSTATE FLOOR FNONCT
syn keyword sasFunction	FNOTE FOPEN FOPTNAME FOPTNUM FPOINT FPOS
syn keyword sasFunction	FPUT FREAD FREWIND FRLEN FSEP FUZZ FWRITE
syn keyword sasFunction	GAMINV GAMMA GETOPTION GETVARC GETVARN HBOUND
syn keyword sasFunction	HMS HOSTHELP HOUR IBESSEL INDEX INDEXC
syn keyword sasFunction	INDEXW INPUT INPUTC INPUTN INT INTCK INTNX
syn keyword sasFunction	INTRR IRR JBESSEL JULDATE KURTOSIS LAG LBOUND
syn keyword sasFunction	LEFT LENGTH LGAMMA LIBNAME LIBREF LOG LOG10
syn keyword sasFunction	LOG2 LOGPDF LOGPMF LOGSDF LOWCASE MAX MDY
syn keyword sasFunction	MEAN MIN MINUTE MOD MONTH MOPEN MORT N
syn keyword sasFunction	NETPV NMISS NORMAL NOTE NPV OPEN ORDINAL
syn keyword sasFunction	PATHNAME PDF PEEK PEEKC PMF POINT POISSON POKE
syn keyword sasFunction	PROBBETA PROBBNML PROBCHI PROBF PROBGAM
syn keyword sasFunction	PROBHYPR PROBIT PROBNEGB PROBNORM PROBT PUT
syn keyword sasFunction	PUTC PUTN QTR QUOTE RANBIN RANCAU RANEXP
syn keyword sasFunction	RANGAM RANGE RANK RANNOR RANPOI RANTBL RANTRI
syn keyword sasFunction	RANUNI REPEAT RESOLVE REVERSE REWIND RIGHT
syn keyword sasFunction	ROUND SAVING SCAN SDF SECOND SIGN SIN SINH
syn keyword sasFunction	SKEWNESS SOUNDEX SPEDIS SQRT STD STDERR STFIPS
syn keyword sasFunction	STNAME STNAMEL SUBSTR SUM SYMGET SYSGET SYSMSG
syn keyword sasFunction	SYSPROD SYSRC SYSTEM TAN TANH TIME TIMEPART
syn keyword sasFunction	TINV TNONCT TODAY TRANSLATE TRANWRD TRIGAMMA
syn keyword sasFunction	TRIM TRIMN TRUNC UNIFORM UPCASE USS VAR
syn keyword sasFunction	VARFMT VARINFMT VARLABEL VARLEN VARNAME
syn keyword sasFunction	VARNUM VARRAY VARRAYX VARTYPE VERIFY VFORMAT
syn keyword sasFunction	VFORMATD VFORMATDX VFORMATN VFORMATNX VFORMATW
syn keyword sasFunction	VFORMATWX VFORMATX VINARRAY VINARRAYX VINFORMAT
syn keyword sasFunction	VINFORMATD VINFORMATDX VINFORMATN VINFORMATNX
syn keyword sasFunction	VINFORMATW VINFORMATWX VINFORMATX VLABEL
syn keyword sasFunction	VLABELX VLENGTH VLENGTHX VNAME VNAMEX VTYPE
syn keyword sasFunction	VTYPEX WEEKDAY YEAR YYQ ZIPFIPS ZIPNAME ZIPNAMEL
syn keyword sasFunction	ZIPSTATE

" Handy settings for using vim with log files
syn keyword sasLogMsg	NOTE
syn keyword sasWarnMsg	WARNING
syn keyword sasErrMsg	ERROR

" Always contained in a comment (Bob Heckel)
syn keyword sasTodo	TODO TBD FIXME contained

" These don't fit anywhere else (Bob Heckel).
" Added others that were missing.
syn keyword sasUnderscore	_ALL_ _AUTOMATIC_ _CHARACTER_ _INFILE_ _N_ _NAME_ _NULL_ _NUMERIC_ _USER_ _WEBOUT_

" End of SAS Functions

"  Define the default highlighting.
"  Only when an item doesn't have highlighting yet


" Default sas enhanced editor color syntax
hi sComment	term=bold cterm=NONE ctermfg=Green ctermbg=Black gui=NONE guifg=DarkGreen guibg=White
hi sCard	term=bold cterm=NONE ctermfg=Black ctermbg=Yellow gui=NONE guifg=Black guibg=LightYellow
hi sDate_Time	term=NONE cterm=bold ctermfg=Green ctermbg=Black gui=bold guifg=SeaGreen guibg=White
hi sKeyword	term=NONE cterm=NONE ctermfg=Blue  ctermbg=Black gui=NONE guifg=Blue guibg=White
hi sFmtInfmt	term=NONE cterm=NONE ctermfg=LightGreen ctermbg=Black gui=NONE guifg=SeaGreen guibg=White
hi sString	term=NONE cterm=NONE ctermfg=Magenta ctermbg=Black gui=NONE guifg=Purple guibg=White
hi sText	term=NONE cterm=NONE ctermfg=White ctermbg=Black gui=bold guifg=Black guibg=White
hi sNumber	term=NONE cterm=bold ctermfg=Green ctermbg=Black gui=bold guifg=SeaGreen guibg=White
hi sProc	term=NONE cterm=bold ctermfg=Blue ctermbg=Black gui=bold guifg=Navy guibg=White
hi sSection	term=NONE cterm=bold ctermfg=Blue ctermbg=Black gui=bold guifg=Navy guibg=White
hi mDefine	term=NONE cterm=bold ctermfg=White ctermbg=Black gui=bold guifg=Black guibg=White
hi mKeyword	term=NONE cterm=NONE ctermfg=Blue ctermbg=Black gui=NONE guifg=Blue guibg=White
hi mReference	term=NONE cterm=bold ctermfg=White ctermbg=Black gui=bold guifg=Blue guibg=White
hi mSection	term=NONE cterm=NONE ctermfg=Blue ctermbg=Black gui=bold guifg=Navy guibg=White
hi mText	term=NONE cterm=NONE ctermfg=White ctermbg=Black gui=bold guifg=Black guibg=White

" Colors that closely match SAS log colors for default color scheme
hi lError	term=NONE cterm=NONE ctermfg=Red ctermbg=Black gui=none guifg=Red guibg=White
hi lWarning	term=NONE cterm=NONE ctermfg=Green ctermbg=Black gui=none guifg=Green guibg=White
hi lNote	term=NONE cterm=NONE ctermfg=Cyan ctermbg=Black gui=none guifg=Blue guibg=White


" Special hilighting for the SAS proc section

hi def link sasComment	sComment
hi def link sasConditional	sKeyword
hi def link sasStep		sSection
hi def link sasFunction	sKeyword
hi def link sasMacro	mKeyword
hi def link sasMacroVar	NonText
hi def link sasNumber	sNumber
hi def link sasStatement	sKeyword
hi def link sasString	sString
hi def link sasProc		sProc
" (Bob Heckel)
hi def link sasTodo		Todo
hi def link sasErrMsg	lError
hi def link sasWarnMsg	lWarning
hi def link sasLogMsg	lNote
hi def link sasCards	sCard
" (Bob Heckel)
hi def link sasUnderscore	PreProc

" Syncronize from beginning to keep large blocks from losing
" syntax coloring while moving through code.
syn sync fromstart

let b:current_syntax = "sas"

" vim: ts=8
