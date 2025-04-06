" Vim syntax file
" Language: Essbase script
" Maintainer:	Raul Segura Acevedo <raulseguraaceved@netscape.net>
" Last change:	2011 Dec 25 by Thilo Six

" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

let s:cpo_save = &cpo
set cpo&vim

" folds: fix/endfix and comments
sy	region	EssFold start="\<Fix" end="EndFix" transparent fold

sy	keyword	cscTodo contained TODO FIXME XXX

" cscCommentGroup allows adding matches for special things in comments
sy	cluster cscCommentGroup contains=cscTodo

" Strings in quotes
sy	match	cscError	'"'
sy	match	cscString	'"[^"]*"'

"when wanted, highlight trailing white space
if exists("csc_space_errors")
	if !exists("csc_no_trail_space_error")
		sy	match	cscSpaceE	"\s\+$"
	endif
	if !exists("csc_no_tab_space_error")
		sy	match	cscSpaceE	" \+\t"me=e-1
	endif
endif

"catch errors caused by wrong parenthesis and brackets
sy	cluster	cscParenGroup	contains=cscParenE,@cscCommentGroup,cscUserCont,cscBitField,cscFormat,cscNumber,cscFloat,cscOctal,cscNumbers,cscIfError,cscComW,cscCom,cscFormula,cscBPMacro
sy	region	cscParen	transparent start='(' end=')' contains=ALLBUT,@cscParenGroup
sy	match	cscParenE	")"

"integer number, or floating point number without a dot and with "f".
sy	case	ignore
sy	match	cscNumbers	transparent "\<\d\|\.\d" contains=cscNumber,cscFloat,cscOctal
sy	match	cscNumber	contained "\d\+\(u\=l\{0,2}\|ll\=u\)\>"
"hex number
sy	match	cscNumber	contained "0x\x\+\(u\=l\{0,2}\|ll\=u\)\>"
" Flag the first zero of an octal number as something special
sy	match	cscOctal	contained "0\o\+\(u\=l\{0,2}\|ll\=u\)\>"
sy	match	cscFloat	contained "\d\+f"
"floating point number, with dot, optional exponent
sy	match	cscFloat	contained "\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\="
"floating point number, starting with a dot, optional exponent
sy	match	cscFloat	contained "\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, without dot, with exponent
sy	match	cscFloat	contained "\d\+e[-+]\=\d\+[fl]\=\>"

sy	region	cscComment	start="/\*" end="\*/" contains=@cscCommentGroup,cscSpaceE fold
sy	match	cscCommentE	"\*/"

sy	keyword	cscIfError	IF ELSE ENDIF ELSEIF
sy	keyword	cscCondition	contained IF ELSE ENDIF ELSEIF
sy	keyword	cscFunction	contained VARPER VAR UDA TRUNCATE SYD SUMRANGE SUM
sy	keyword	cscFunction	contained STDDEVRANGE STDDEV SPARENTVAL SLN SIBLINGS SHIFT
sy	keyword	cscFunction	contained SANCESTVAL RSIBLINGS ROUND REMAINDER RELATIVE PTD
sy	keyword	cscFunction	contained PRIOR POWER PARENTVAL NPV NEXT MOD MINRANGE MIN
sy	keyword	cscFunction	contained MDSHIFT MDPARENTVAL MDANCESTVAL MAXRANGE MAX MATCH
sy	keyword	cscFunction	contained LSIBLINGS LEVMBRS LEV
sy	keyword	cscFunction	contained ISUDA ISSIBLING ISSAMELEV ISSAMEGEN ISPARENT ISMBR
sy	keyword	cscFunction	contained ISLEV ISISIBLING ISIPARENT ISIDESC ISICHILD ISIBLINGS
sy	keyword	cscFunction	contained ISIANCEST ISGEN ISDESC ISCHILD ISANCEST ISACCTYPE
sy	keyword	cscFunction	contained IRSIBLINGS IRR INTEREST INT ILSIBLINGS IDESCENDANTS
sy	keyword	cscFunction	contained ICHILDREN IANCESTORS IALLANCESTORS
sy	keyword	cscFunction	contained GROWTH GENMBRS GEN FACTORIAL DISCOUNT DESCENDANTS
sy	keyword	cscFunction	contained DECLINE CHILDREN CURRMBRRANGE CURLEV CURGEN
sy	keyword	cscFunction	contained COMPOUNDGROWTH COMPOUND AVGRANGE AVG ANCESTVAL
sy	keyword	cscFunction	contained ANCESTORS ALLANCESTORS ACCUM ABS
sy	keyword	cscFunction	contained @VARPER @VAR @UDA @TRUNCATE @SYD @SUMRANGE @SUM
sy	keyword	cscFunction	contained @STDDEVRANGE @STDDEV @SPARENTVAL @SLN @SIBLINGS @SHIFT
sy	keyword	cscFunction	contained @SANCESTVAL @RSIBLINGS @ROUND @REMAINDER @RELATIVE @PTD
sy	keyword	cscFunction	contained @PRIOR @POWER @PARENTVAL @NPV @NEXT @MOD @MINRANGE @MIN
sy	keyword	cscFunction	contained @MDSHIFT @MDPARENTVAL @MDANCESTVAL @MAXRANGE @MAX @MATCH
sy	keyword	cscFunction	contained @LSIBLINGS @LEVMBRS @LEV
sy	keyword	cscFunction	contained @ISUDA @ISSIBLING @ISSAMELEV @ISSAMEGEN @ISPARENT @ISMBR
sy	keyword	cscFunction	contained @ISLEV @ISISIBLING @ISIPARENT @ISIDESC @ISICHILD @ISIBLINGS
sy	keyword	cscFunction	contained @ISIANCEST @ISGEN @ISDESC @ISCHILD @ISANCEST @ISACCTYPE
sy	keyword	cscFunction	contained @IRSIBLINGS @IRR @INTEREST @INT @ILSIBLINGS @IDESCENDANTS
sy	keyword	cscFunction	contained @ICHILDREN @IANCESTORS @IALLANCESTORS
sy	keyword	cscFunction	contained @GROWTH @GENMBRS @GEN @FACTORIAL @DISCOUNT @DESCENDANTS
sy	keyword	cscFunction	contained @DECLINE @CHILDREN @CURRMBRRANGE @CURLEV @CURGEN
sy	keyword	cscFunction	contained @COMPOUNDGROWTH @COMPOUND @AVGRANGE @AVG @ANCESTVAL
sy	keyword	cscFunction	contained @ANCESTORS @ALLANCESTORS @ACCUM @ABS
sy	match	cscFunction	contained "@"
sy	match	cscError	"@\s*\a*" contains=cscFunction

sy	match	cscStatement	"&"
sy	keyword	cscStatement	AGG ARRAY VAR CCONV CLEARDATA DATACOPY

sy	match	cscComE	contained "^\s*CALC.*"
sy	match	cscComE	contained "^\s*CLEARBLOCK.*"
sy	match	cscComE	contained "^\s*SET.*"
sy	match	cscComE	contained "^\s*FIX"
sy	match	cscComE	contained "^\s*ENDFIX"
sy	match	cscComE	contained "^\s*ENDLOOP"
sy	match	cscComE	contained "^\s*LOOP"
" sy	keyword	cscCom	FIX ENDFIX LOOP ENDLOOP

sy	match	cscComW	"^\s*CALC.*"
sy	match	cscCom	"^\s*CALC\s*ALL"
sy	match	cscCom	"^\s*CALC\s*AVERAGE"
sy	match	cscCom	"^\s*CALC\s*DIM"
sy	match	cscCom	"^\s*CALC\s*FIRST"
sy	match	cscCom	"^\s*CALC\s*LAST"
sy	match	cscCom	"^\s*CALC\s*TWOPASS"

sy	match	cscComW	"^\s*CLEARBLOCK.*"
sy	match	cscCom	"^\s*CLEARBLOCK\s\+ALL"
sy	match	cscCom	"^\s*CLEARBLOCK\s\+UPPER"
sy	match	cscCom	"^\s*CLEARBLOCK\s\+NONINPUT"

sy	match	cscComW	"^\s*\<SET.*"
sy	match	cscCom	"^\s*\<SET\s\+Commands"
sy	match	cscCom	"^\s*\<SET\s\+AGGMISSG"
sy	match	cscCom	"^\s*\<SET\s\+CACHE"
sy	match	cscCom	"^\s*\<SET\s\+CALCHASHTBL"
sy	match	cscCom	"^\s*\<SET\s\+CLEARUPDATESTATUS"
sy	match	cscCom	"^\s*\<SET\s\+FRMLBOTTOMUP"
sy	match	cscCom	"^\s*\<SET\s\+LOCKBLOCK"
sy	match	cscCom	"^\s*\<SET\s\+MSG"
sy	match	cscCom	"^\s*\<SET\s\+NOTICE"
sy	match	cscCom	"^\s*\<SET\s\+UPDATECALC"
sy	match	cscCom	"^\s*\<SET\s\+UPTOLOCAL"

sy	keyword	cscBPMacro	contained !LoopOnAll !LoopOnLevel !LoopOnSelected
sy	keyword	cscBPMacro	contained !CurrentMember !LoopOnDimensions !CurrentDimension
sy	keyword	cscBPMacro	contained !CurrentOtherLoopDimension !LoopOnOtherLoopDimensions
sy	keyword	cscBPMacro	contained !EndLoop !AllMembers !SelectedMembers !If !Else !EndIf
sy	keyword	cscBPMacro	contained LoopOnAll LoopOnLevel LoopOnSelected
sy	keyword	cscBPMacro	contained CurrentMember LoopOnDimensions CurrentDimension
sy	keyword	cscBPMacro	contained CurrentOtherLoopDimension LoopOnOtherLoopDimensions
sy	keyword	cscBPMacro	contained EndLoop AllMembers SelectedMembers If Else EndIf
sy	match	cscBPMacro	contained	"!"
sy	match	cscBPW	"!\s*\a*"	contains=cscBPmacro

" when wanted, highlighting lhs members or errors in assignments (may lag the editing)
if exists("csc_asignment")
	sy	match	cscEqError	'\("[^"]*"\s*\|[^][\t !%()*+,--/:;<=>{}~]\+\s*\|->\s*\)*=\([^=]\@=\|$\)'
	sy	region	cscFormula	transparent matchgroup=cscVarName start='\("[^"]*"\|[^][\t !%()*+,--/:;<=>{}~]\+\)\s*=\([^=]\@=\|\n\)' skip='"[^"]*"' end=';' contains=ALLBUT,cscFormula,cscFormulaIn,cscBPMacro,cscCondition
	sy	region	cscFormulaIn	matchgroup=cscVarName transparent start='\("[^"]*"\|[^][\t !%()*+,--/:;<=>{}~]\+\)\(->\("[^"]*"\|[^][\t !%()*+,--/:;<=>{}~]\+\)\)*\s*=\([^=]\@=\|$\)' skip='"[^"]*"' end=';' contains=ALLBUT,cscFormula,cscFormulaIn,cscBPMacro,cscCondition contained
	sy	match	cscEq	"=="
endif

if !exists("csc_minlines")
	let csc_minlines = 50	" mostly for () constructs
endif
exec "sy sync ccomment cscComment minlines=" . csc_minlines

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi cscVarName term=bold ctermfg=9 gui=bold guifg=blue

hi def link cscNumber	Number
hi def link cscOctal	Number
hi def link cscFloat	Float
hi def link cscParenE	Error
hi def link cscCommentE	Error
hi def link cscSpaceE	Error
hi def link cscError	Error
hi def link cscString	String
hi def link cscComment	Comment
hi def link cscTodo		Todo
hi def link cscStatement	Statement
hi def link cscIfError	Error
hi def link cscEqError	Error
hi def link cscFunction	Statement
hi def link cscCondition	Statement
hi def link cscWarn		WarningMsg

hi def link cscComE	Error
hi def link cscCom	Statement
hi def link cscComW	WarningMsg

hi def link cscBPMacro	Identifier
hi def link cscBPW		WarningMsg


let b:current_syntax = "csc"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8
