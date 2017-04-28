" Vim syntax file
" Language:		bin using xxd
" Maintainer:	Charles E. Campbell <NdrOchipS@PcampbellAfamily.Mbiz>
" Last Change:	Oct 23, 2014
" Version:		8
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
" Only when an item doesn't have highlighting yet
command -nargs=+ HiLink hi def link <args>

HiLink xxdAddress	Constant
HiLink xxdSep		Identifier
HiLink xxdAscii	Statement

delcommand HiLink

let b:current_syntax = "xxd"

" vim: ts=4
