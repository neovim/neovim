" Vim syntax file
" Language:	Remind
" Maintainer:	Davide Alberani <da@erlug.linux.it>
" Last Change:	02 Nov 2015
" Version:	0.7
" URL:		http://ismito.it/vim/syntax/remind.vim
"
" Remind is a sophisticated calendar and alarm program.
" You can download remind from:
"   https://www.roaringpenguin.com/products/remind
"
" Changelog
" version 0.7: updated email and link
" version 0.6: added THROUGH keyword (courtesy of Ben Orchard)

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" shut case off.
syn case ignore

syn keyword remindCommands	REM OMIT SET FSET UNSET
syn keyword remindExpiry	UNTIL FROM SCANFROM SCAN WARN SCHED THROUGH
syn keyword remindTag		PRIORITY TAG
syn keyword remindTimed		AT DURATION
syn keyword remindMove		ONCE SKIP BEFORE AFTER
syn keyword remindSpecial	INCLUDE INC BANNER PUSH-OMIT-CONTEXT PUSH CLEAR-OMIT-CONTEXT CLEAR POP-OMIT-CONTEXT POP COLOR
syn keyword remindRun		MSG MSF RUN CAL SATISFY SPECIAL PS PSFILE SHADE MOON
syn keyword remindConditional	IF ELSE ENDIF IFTRIG
syn keyword remindDebug		DEBUG DUMPVARS DUMP ERRMSG FLUSH PRESERVE
syn match remindComment		"#.*$"
syn region remindString		start=+'+ end=+'+ skip=+\\\\\|\\'+ oneline
syn region remindString		start=+"+ end=+"+ skip=+\\\\\|\\"+ oneline
syn match remindVar		"\$[_a-zA-Z][_a-zA-Z0-9]*"
syn match remindSubst		"%[^ ]"
syn match remindAdvanceNumber	"\(\*\|+\|-\|++\|--\)[0-9]\+"
" XXX: use different separators for dates and times?
syn match remindDateSeparators	"[/:@\.-]" contained
syn match remindTimes		"[0-9]\{1,2}[:\.][0-9]\{1,2}" contains=remindDateSeparators
" XXX: why not match only valid dates?  Ok, checking for 'Feb the 30' would
"       be impossible, but at least check for valid months and times.
syn match remindDates		"'[0-9]\{4}[/-][0-9]\{1,2}[/-][0-9]\{1,2}\(@[0-9]\{1,2}[:\.][0-9]\{1,2}\)\?'" contains=remindDateSeparators
" This will match trailing whitespaces that seem to break rem2ps.
" Courtesy of Michael Dunn.
syn match remindWarning		display excludenl "\S\s\+$"ms=s+1



hi def link remindCommands		Function
hi def link remindExpiry		Repeat
hi def link remindTag		Label
hi def link remindTimed		Statement
hi def link remindMove		Statement
hi def link remindSpecial		Include
hi def link remindRun		Function
hi def link remindConditional	Conditional
hi def link remindComment		Comment
hi def link remindTimes		String
hi def link remindString		String
hi def link remindDebug		Debug
hi def link remindVar		Identifier
hi def link remindSubst		Constant
hi def link remindAdvanceNumber	Number
hi def link remindDateSeparators	Comment
hi def link remindDates		String
hi def link remindWarning		Error


let b:current_syntax = "remind"

" vim: ts=8 sw=2
