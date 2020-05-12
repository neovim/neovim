" Vim syntax file
" Language:	Renderman shader language
" Maintainer:	Dan Piponi <dan@tanelorn.demon.co.uk>
" Last Change:	2001 May 09

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" A bunch of useful Renderman keywords including special
" RenderMan control structures
syn keyword slStatement	break return continue
syn keyword slConditional	if else
syn keyword slRepeat		while for
syn keyword slRepeat		illuminance illuminate solar

syn keyword slTodo contained	TODO FIXME XXX

" String and Character constants
" Highlight special characters (those which have a backslash) differently
syn match slSpecial contained	"\\[0-9][0-9][0-9]\|\\."
syn region slString		start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=slSpecial
syn match slCharacter		"'[^\\]'"
syn match slSpecialCharacter	"'\\.'"
syn match slSpecialCharacter	"'\\[0-9][0-9]'"
syn match slSpecialCharacter	"'\\[0-9][0-9][0-9]'"

"catch errors caused by wrong parenthesis
syn region slParen		transparent start='(' end=')' contains=ALLBUT,slParenError,slIncluded,slSpecial,slTodo,slUserLabel
syn match slParenError		")"
syn match slInParen contained	"[{}]"

"integer number, or floating point number without a dot and with "f".
syn case ignore
syn match slNumber		"\<[0-9]\+\(u\=l\=\|lu\|f\)\>"
"floating point number, with dot, optional exponent
syn match slFloat		"\<[0-9]\+\.[0-9]*\(e[-+]\=[0-9]\+\)\=[fl]\=\>"
"floating point number, starting with a dot, optional exponent
syn match slFloat		"\.[0-9]\+\(e[-+]\=[0-9]\+\)\=[fl]\=\>"
"floating point number, without dot, with exponent
syn match slFloat		"\<[0-9]\+e[-+]\=[0-9]\+[fl]\=\>"
"hex number
syn match slNumber		"\<0x[0-9a-f]\+\(u\=l\=\|lu\)\>"
"syn match slIdentifier	"\<[a-z_][a-z0-9_]*\>"
syn case match

if exists("sl_comment_strings")
  " A comment can contain slString, slCharacter and slNumber.
  " But a "*/" inside a slString in a slComment DOES end the comment!  So we
  " need to use a special type of slString: slCommentString, which also ends on
  " "*/", and sees a "*" at the start of the line as comment again.
  " Unfortunately this doesn't very well work for // type of comments :-(
  syntax match slCommentSkip	contained "^\s*\*\($\|\s\+\)"
  syntax region slCommentString	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ end=+\*/+me=s-1 contains=slSpecial,slCommentSkip
  syntax region slComment2String	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ end="$" contains=slSpecial
  syntax region slComment	start="/\*" end="\*/" contains=slTodo,slCommentString,slCharacter,slNumber
else
  syn region slComment		start="/\*" end="\*/" contains=slTodo
endif
syntax match slCommentError	"\*/"

syn keyword slOperator	sizeof
syn keyword slType		float point color string vector normal matrix void
syn keyword slStorageClass	varying uniform extern
syn keyword slStorageClass	light surface volume displacement transformation imager
syn keyword slVariable	Cs Os P dPdu dPdv N Ng u v du dv s t
syn keyword slVariable L Cl Ol E I ncomps time Ci Oi
syn keyword slVariable Ps alpha
syn keyword slVariable dtime dPdtime

syn sync ccomment slComment minlines=10

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link slLabel	Label
hi def link slUserLabel	Label
hi def link slConditional	Conditional
hi def link slRepeat	Repeat
hi def link slCharacter	Character
hi def link slSpecialCharacter slSpecial
hi def link slNumber	Number
hi def link slFloat	Float
hi def link slParenError	slError
hi def link slInParen	slError
hi def link slCommentError	slError
hi def link slOperator	Operator
hi def link slStorageClass	StorageClass
hi def link slError	Error
hi def link slStatement	Statement
hi def link slType		Type
hi def link slCommentError	slError
hi def link slCommentString slString
hi def link slComment2String slString
hi def link slCommentSkip	slComment
hi def link slString	String
hi def link slComment	Comment
hi def link slSpecial	SpecialChar
hi def link slTodo	Todo
hi def link slVariable	Identifier
"hi def link slIdentifier	Identifier


let b:current_syntax = "sl"

" vim: ts=8
