" Vim syntax file
" Language:	Renderman shader language
" Maintainer:	Dan Piponi <dan@tanelorn.demon.co.uk>
" Last Change:	2001 May 09

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_sl_syntax_inits")
  if version < 508
    let did_sl_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink slLabel	Label
  HiLink slUserLabel	Label
  HiLink slConditional	Conditional
  HiLink slRepeat	Repeat
  HiLink slCharacter	Character
  HiLink slSpecialCharacter slSpecial
  HiLink slNumber	Number
  HiLink slFloat	Float
  HiLink slParenError	slError
  HiLink slInParen	slError
  HiLink slCommentError	slError
  HiLink slOperator	Operator
  HiLink slStorageClass	StorageClass
  HiLink slError	Error
  HiLink slStatement	Statement
  HiLink slType		Type
  HiLink slCommentError	slError
  HiLink slCommentString slString
  HiLink slComment2String slString
  HiLink slCommentSkip	slComment
  HiLink slString	String
  HiLink slComment	Comment
  HiLink slSpecial	SpecialChar
  HiLink slTodo	Todo
  HiLink slVariable	Identifier
  "HiLink slIdentifier	Identifier

  delcommand HiLink
endif

let b:current_syntax = "sl"

" vim: ts=8
