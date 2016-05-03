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

if version < 600
  syntax clear
elseif exists("b:current_syntax")
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


if version >= 508 || !exists("did_remind_syn_inits")
  if version < 508
    let did_remind_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink remindCommands		Function
  HiLink remindExpiry		Repeat
  HiLink remindTag		Label
  HiLink remindTimed		Statement
  HiLink remindMove		Statement
  HiLink remindSpecial		Include
  HiLink remindRun		Function
  HiLink remindConditional	Conditional
  HiLink remindComment		Comment
  HiLink remindTimes		String
  HiLink remindString		String
  HiLink remindDebug		Debug
  HiLink remindVar		Identifier
  HiLink remindSubst		Constant
  HiLink remindAdvanceNumber	Number
  HiLink remindDateSeparators	Comment
  HiLink remindDates		String
  HiLink remindWarning		Error

  delcommand HiLink
endif

let b:current_syntax = "remind"

" vim: ts=8 sw=2
