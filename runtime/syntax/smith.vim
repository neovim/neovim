" Vim syntax file
" Language:	SMITH
" Maintainer:	Rafal M. Sulejman <rms@poczta.onet.pl>
" Last Change:	21.07.2000

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore


syn match smithComment ";.*$"

syn match smithNumber		"\<[+-]*[0-9]\d*\>"

syn match smithRegister		"R[\[]*[0-9]*[\]]*"

syn match smithKeyword	"COR\|MOV\|MUL\|NOT\|STOP\|SUB\|NOP\|BLA\|REP"

syn region smithString		start=+"+  skip=+\\\\\|\\"+  end=+"+


syn case match

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_smith_syntax_inits")
  if version < 508
    let did_smith_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink smithRegister	Identifier
  HiLink smithKeyword	Keyword
	HiLink smithComment Comment
	HiLink smithString String
  HiLink smithNumber	Number

	delcommand HiLink
endif

let b:current_syntax = "smith"

" vim: ts=2
