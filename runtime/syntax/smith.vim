" Vim syntax file
" Language:	SMITH
" Maintainer:	Rafal M. Sulejman <rms@poczta.onet.pl>
" Last Change:	21.07.2000

" quit when a syntax file was already loaded
if exists("b:current_syntax")
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
" Only when an item doesn't have highlighting yet
command -nargs=+ HiLink hi def link <args>

HiLink smithRegister	Identifier
HiLink smithKeyword	Keyword
HiLink smithComment Comment
HiLink smithString String
HiLink smithNumber	Number

delcommand HiLink

let b:current_syntax = "smith"

" vim: ts=2
