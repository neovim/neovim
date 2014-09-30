" Vim syntax file
" Language:	purify log files
" Maintainer:	Gautam H. Mudunuri <gmudunur@informatica.com>
" Last Change:	2003 May 11

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Purify header
syn match purifyLogHeader      "^\*\*\*\*.*$"

" Informational messages
syn match purifyLogFIU "^FIU:.*$"
syn match purifyLogMAF "^MAF:.*$"
syn match purifyLogMIU "^MIU:.*$"
syn match purifyLogSIG "^SIG:.*$"
syn match purifyLogWPF "^WPF:.*$"
syn match purifyLogWPM "^WPM:.*$"
syn match purifyLogWPN "^WPN:.*$"
syn match purifyLogWPR "^WPR:.*$"
syn match purifyLogWPW "^WPW:.*$"
syn match purifyLogWPX "^WPX:.*$"

" Warning messages
syn match purifyLogABR "^ABR:.*$"
syn match purifyLogBSR "^BSR:.*$"
syn match purifyLogBSW "^BSW:.*$"
syn match purifyLogFMR "^FMR:.*$"
syn match purifyLogMLK "^MLK:.*$"
syn match purifyLogMSE "^MSE:.*$"
syn match purifyLogPAR "^PAR:.*$"
syn match purifyLogPLK "^PLK:.*$"
syn match purifyLogSBR "^SBR:.*$"
syn match purifyLogSOF "^SOF:.*$"
syn match purifyLogUMC "^UMC:.*$"
syn match purifyLogUMR "^UMR:.*$"

" Corrupting messages
syn match purifyLogABW "^ABW:.*$"
syn match purifyLogBRK "^BRK:.*$"
syn match purifyLogFMW "^FMW:.*$"
syn match purifyLogFNH "^FNH:.*$"
syn match purifyLogFUM "^FUM:.*$"
syn match purifyLogMRE "^MRE:.*$"
syn match purifyLogSBW "^SBW:.*$"

" Fatal messages
syn match purifyLogCOR "^COR:.*$"
syn match purifyLogNPR "^NPR:.*$"
syn match purifyLogNPW "^NPW:.*$"
syn match purifyLogZPR "^ZPR:.*$"
syn match purifyLogZPW "^ZPW:.*$"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_purifyLog_syntax_inits")
  if version < 508
    let did_purifyLog_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

	HiLink purifyLogFIU purifyLogInformational
	HiLink purifyLogMAF purifyLogInformational
	HiLink purifyLogMIU purifyLogInformational
	HiLink purifyLogSIG purifyLogInformational
	HiLink purifyLogWPF purifyLogInformational
	HiLink purifyLogWPM purifyLogInformational
	HiLink purifyLogWPN purifyLogInformational
	HiLink purifyLogWPR purifyLogInformational
	HiLink purifyLogWPW purifyLogInformational
	HiLink purifyLogWPX purifyLogInformational

	HiLink purifyLogABR purifyLogWarning
	HiLink purifyLogBSR purifyLogWarning
	HiLink purifyLogBSW purifyLogWarning
	HiLink purifyLogFMR purifyLogWarning
	HiLink purifyLogMLK purifyLogWarning
	HiLink purifyLogMSE purifyLogWarning
	HiLink purifyLogPAR purifyLogWarning
	HiLink purifyLogPLK purifyLogWarning
	HiLink purifyLogSBR purifyLogWarning
	HiLink purifyLogSOF purifyLogWarning
	HiLink purifyLogUMC purifyLogWarning
	HiLink purifyLogUMR purifyLogWarning

	HiLink purifyLogABW purifyLogCorrupting
	HiLink purifyLogBRK purifyLogCorrupting
	HiLink purifyLogFMW purifyLogCorrupting
	HiLink purifyLogFNH purifyLogCorrupting
	HiLink purifyLogFUM purifyLogCorrupting
	HiLink purifyLogMRE purifyLogCorrupting
	HiLink purifyLogSBW purifyLogCorrupting

	HiLink purifyLogCOR purifyLogFatal
	HiLink purifyLogNPR purifyLogFatal
	HiLink purifyLogNPW purifyLogFatal
	HiLink purifyLogZPR purifyLogFatal
	HiLink purifyLogZPW purifyLogFatal

	HiLink purifyLogHeader		Comment
	HiLink purifyLogInformational	PreProc
	HiLink purifyLogWarning		Type
	HiLink purifyLogCorrupting	Error
	HiLink purifyLogFatal		Error

	delcommand HiLink
endif

let b:current_syntax = "purifylog"

" vim:ts=8
