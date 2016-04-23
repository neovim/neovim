" Vim syntax file
" Language:		bin using xxd
" Maintainer:	Charles E. Campbell <NdrOchipS@PcampbellAfamily.Mbiz>
" Last Change:	Oct 23, 2014
" Version:		8
" Notes:		use :help xxd   to see how to invoke it
" URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_XXD

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn match xxdAddress			"^[0-9a-f]\+:"		contains=xxdSep
syn match xxdSep	contained	":"
syn match xxdAscii				"  .\{,16\}\r\=$"hs=s+2	contains=xxdDot
syn match xxdDot	contained	"[.\r]"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_xxd_syntax_inits")
  if version < 508
    let did_xxd_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

 HiLink xxdAddress	Constant
 HiLink xxdSep		Identifier
 HiLink xxdAscii	Statement

 delcommand HiLink
endif

let b:current_syntax = "xxd"

" vim: ts=4
