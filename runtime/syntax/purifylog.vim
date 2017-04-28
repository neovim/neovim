" Vim syntax file
" Language:	purify log files
" Maintainer:	Gautam H. Mudunuri <gmudunur@informatica.com>
" Last Change:	2003 May 11

" quit when a syntax file was already loaded
if exists("b:current_syntax")
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
" Only when an item doesn't have highlighting yet

hi def link purifyLogFIU purifyLogInformational
hi def link purifyLogMAF purifyLogInformational
hi def link purifyLogMIU purifyLogInformational
hi def link purifyLogSIG purifyLogInformational
hi def link purifyLogWPF purifyLogInformational
hi def link purifyLogWPM purifyLogInformational
hi def link purifyLogWPN purifyLogInformational
hi def link purifyLogWPR purifyLogInformational
hi def link purifyLogWPW purifyLogInformational
hi def link purifyLogWPX purifyLogInformational

hi def link purifyLogABR purifyLogWarning
hi def link purifyLogBSR purifyLogWarning
hi def link purifyLogBSW purifyLogWarning
hi def link purifyLogFMR purifyLogWarning
hi def link purifyLogMLK purifyLogWarning
hi def link purifyLogMSE purifyLogWarning
hi def link purifyLogPAR purifyLogWarning
hi def link purifyLogPLK purifyLogWarning
hi def link purifyLogSBR purifyLogWarning
hi def link purifyLogSOF purifyLogWarning
hi def link purifyLogUMC purifyLogWarning
hi def link purifyLogUMR purifyLogWarning

hi def link purifyLogABW purifyLogCorrupting
hi def link purifyLogBRK purifyLogCorrupting
hi def link purifyLogFMW purifyLogCorrupting
hi def link purifyLogFNH purifyLogCorrupting
hi def link purifyLogFUM purifyLogCorrupting
hi def link purifyLogMRE purifyLogCorrupting
hi def link purifyLogSBW purifyLogCorrupting

hi def link purifyLogCOR purifyLogFatal
hi def link purifyLogNPR purifyLogFatal
hi def link purifyLogNPW purifyLogFatal
hi def link purifyLogZPR purifyLogFatal
hi def link purifyLogZPW purifyLogFatal

hi def link purifyLogHeader		Comment
hi def link purifyLogInformational	PreProc
hi def link purifyLogWarning		Type
hi def link purifyLogCorrupting	Error
hi def link purifyLogFatal		Error


let b:current_syntax = "purifylog"

" vim:ts=8
