" Vim syntax file
" Language:		CL
" 			(pronounced alphabetically: "Cee-El".
" 			CL stands for Clever Language,
" 			but the language is CL, not "Clever".
" 			CL was created by Multibase, http://www.mbase.com.au)
" Filename extensions:	*.ent
"			*.eni
" Maintainer:		Philip Uren	<philuSPAX@ieee.org> Remove SPAX spam block
" Version:              6
" Last Change:		Mar 06 2013

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
	syntax clear
elseif exists("b:current_syntax")
	finish
endif

if version >= 600
	setlocal iskeyword=@,48-57,_,-
else
	set iskeyword=@,48-57,_,-
endif

syn case ignore

syn sync lines=300

"If/else/elsif/endif and while/wend mismatch errors
syn match	clifError	"\<wend\>"
syn match	clifError	"\<elsif\>"
syn match	clifError	"\<else\>"
syn match	clifError	"\<endif\>"

syn match	clSpaceError	"\s\+$"

" If and while regions
syn region	clLoop		transparent matchgroup=clWhile start="\<while\>" matchgroup=clWhile end="\<wend\>" contains=ALLBUT,clBreak,clProcedure
syn region	clIf		transparent matchgroup=clConditional start="\<if\>" matchgroup=clConditional end="\<endif\>"   contains=ALLBUT,clBreak,clProcedure

" Make those TODO notes and debugging stand out!
syn keyword	clTodo		contained	TODO BUG DEBUG FIX
syn match	clNeedsWork	contained	"NEED[S]*\s\s*WORK"
syn keyword	clDebug		contained	debug

syn match	clComment	"#.*$"		contains=clTodo,clNeedsWork,@Spell
syn region	clProcedure	oneline		start="^\s*[{}]" end="$"
syn match	clInclude	"^\s*include\s.*"

" We don't put "debug" in the clSetOptions;
" we contain it in clSet so we can make it stand out.
syn keyword	clSetOptions	transparent aauto abort align convert E fill fnum goback hangup justify null_exit output rauto rawprint rawdisplay repeat skip tab trim
syn match	clSet		"^\s*set\s.*" contains=clSetOptions,clDebug

syn match	clPreProc	"^\s*#P.*"

syn keyword	clConditional	else elsif
syn keyword	clWhile		continue endloop
" 'break' needs to be a region so we can sync on it above.
syn region	clBreak		oneline start="^\s*break" end="$"

syn match	clOperator	"[!;|)(:.><+*=-]"

syn match	clNumber	"\<\d\+\(u\=l\=\|lu\|f\)\>"

syn region	clString	matchgroup=clQuote	start=+"+ end=+"+	skip=+\\"+ contains=@Spell
syn region	clString	matchgroup=clQuote	start=+'+ end=+'+	skip=+\\'+ contains=@Spell

syn keyword	clReserved	ERROR EXIT INTERRUPT LOCKED LREPLY MODE MCOL MLINE MREPLY NULL REPLY V1 V2 V3 V4 V5 V6 V7 V8 V9 ZERO BYPASS GOING_BACK AAUTO ABORT ABORT ALIGN BIGE CONVERT FNUM GOBACK HANGUP JUSTIFY NEXIT OUTPUT RAUTO RAWDISPLAY RAWPRINT REPEAT SKIP TAB TRIM LCOUNT PCOUNT PLINES SLINES SCOLS MATCH LMATCH

syn keyword	clFunction	asc asize chr name random slen srandom day getarg getcgi getenv lcase scat sconv sdel skey smult srep substr sword trim ucase match

syn keyword	clStatement	clear clear_eol clear_eos close copy create unique with where empty define define ldefine delay_form delete escape exit_block exit_do exit_process field fork format get getfile getnext getprev goto head join maintain message no_join on_eop on_key on_exit on_delete openin openout openapp pause popenin popenout popenio print put range read redisplay refresh restart_block screen select sleep text unlock write and not or do

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if	version >= 508 || !exists("did_cl_syntax_inits")
	if	version < 508
		let did_cl_syntax_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
	endif

	HiLink clifError	Error
	HiLink clSpaceError	Error
	HiLink clWhile		Repeat
	HiLink clConditional	Conditional
	HiLink clDebug		Debug
	HiLink clNeedsWork	Todo
	HiLink clTodo		Todo
	HiLink clComment	Comment
	HiLink clProcedure	Procedure
	HiLink clBreak		Procedure
	HiLink clInclude	Include
	HiLink clSetOption	Statement
	HiLink clSet		Identifier
	HiLink clPreProc	PreProc
	HiLink clOperator	Operator
	HiLink clNumber		Number
	HiLink clString		String
	HiLink clQuote		Delimiter
	HiLink clReserved	Identifier
	HiLink clFunction	Function
	HiLink clStatement	Statement

	delcommand HiLink
endif

let b:current_syntax = "cl"

" vim: ts=8 sw=8
