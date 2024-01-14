" Vim syntax file
" Language:		bin using xxd
" Maintainer:	Charles E. Campbell <NcampObell@SdrPchip.AorgM-NOSPAM>
" Last Change:	Aug 31, 2016
" Version:		11
" Notes:		use :help xxd   to see how to invoke it
" URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_XXD

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn match xxdAddress			"^[0-9a-f]\+:"		contains=xxdSep
syn match xxdSep	contained	":"
syn match xxdAscii				"  .\{,16\}\r\=$"hs=s+2	contains=xxdDot
syn match xxdDot	contained	"[.\r]"

" Define the default highlighting.
if !exists("skip_xxd_syntax_inits")

 hi def link xxdAddress	Constant
 hi def link xxdSep		Identifier
 hi def link xxdAscii	Statement

endif

let b:current_syntax = "xxd"

" vim: ts=4
