" Vim syntax file
" Language:	MEL (Maya Extension Language)
" Maintainer:	Robert Minsk <egbert@centropolisfx.com>
" Last Change:	May 27 1999
" Based on:	Bram Moolenaar <Bram@vim.org> C syntax file

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" when wanted, highlight trailing white space and spaces before tabs
if exists("mel_space_errors")
  sy match	melSpaceError	"\s\+$"
  sy match	melSpaceError	" \+\t"me=e-1
endif

" A bunch of usefull MEL keyworks
sy keyword	melBoolean	true false yes no on off

sy keyword	melFunction	proc
sy match	melIdentifier	"\$\(\a\|_\)\w*"

sy keyword	melStatement	break continue return
sy keyword	melConditional	if else switch
sy keyword	melRepeat	while for do in
sy keyword	melLabel	case default
sy keyword	melOperator	size eval env exists whatIs
sy keyword	melKeyword	alias
sy keyword	melException	catch error warning

sy keyword	melInclude	source

sy keyword	melType		int float string vector matrix
sy keyword	melStorageClass	global

sy keyword	melDebug	trace

sy keyword	melTodo		contained TODO FIXME XXX

" MEL data types
sy match	melCharSpecial	contained "\\[ntr\\"]"
sy match	melCharError	contained "\\[^ntr\\"]"

sy region	melString	start=+"+ skip=+\\"+ end=+"+ contains=melCharSpecial,melCharError

sy case ignore
sy match	melInteger	"\<\d\+\(e[-+]\=\d\+\)\=\>"
sy match	melFloat	"\<\d\+\(e[-+]\=\d\+\)\=f\>"
sy match	melFloat	"\<\d\+\.\d*\(e[-+]\=\d\+\)\=f\=\>"
sy match	melFloat	"\.\d\+\(e[-+]\=\d\+\)\=f\=\>"
sy case match

sy match	melCommaSemi	contained "[,;]"
sy region	melMatrixVector	start=/<</ end=/>>/ contains=melInteger,melFloat,melIdentifier,melCommaSemi

sy cluster	melGroup	contains=melFunction,melStatement,melConditional,melLabel,melKeyword,melStorageClass,melTODO,melCharSpecial,melCharError,melCommaSemi

" catch errors caused by wrong parenthesis
sy region	melParen	transparent start='(' end=')' contains=ALLBUT,@melGroup,melParenError,melInParen
sy match	melParenError	")"
sy match	melInParen	contained "[{}]"

" comments
sy region	melComment	start="/\*" end="\*/" contains=melTodo,melSpaceError
sy match	melComment	"//.*" contains=melTodo,melSpaceError
sy match	melCommentError "\*/"

sy region	melQuestionColon matchgroup=melConditional transparent start='?' end=':' contains=ALLBUT,@melGroup

if !exists("mel_minlines")
  let mel_minlines=15
endif
exec "sy sync ccomment melComment minlines=" . mel_minlines

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_mel_syntax_inits")
  if version < 508
    let did_mel_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink melBoolean	Boolean
  HiLink melFunction	Function
  HiLink melIdentifier	Identifier
  HiLink melStatement	Statement
  HiLink melConditional Conditional
  HiLink melRepeat	Repeat
  HiLink melLabel	Label
  HiLink melOperator	Operator
  HiLink melKeyword	Keyword
  HiLink melException	Exception
  HiLink melInclude	Include
  HiLink melType	Type
  HiLink melStorageClass StorageClass
  HiLink melDebug	Debug
  HiLink melTodo	Todo
  HiLink melCharSpecial SpecialChar
  HiLink melString	String
  HiLink melInteger	Number
  HiLink melFloat	Float
  HiLink melMatrixVector Float
  HiLink melComment	Comment
  HiLink melError	Error
  HiLink melSpaceError	melError
  HiLink melCharError	melError
  HiLink melParenError	melError
  HiLink melInParen	melError
  HiLink melCommentError melError

  delcommand HiLink
endif

let b:current_syntax = "mel"
