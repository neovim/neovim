" Vim syntax file
" Language:	MEL (Maya Extension Language)
" Maintainer:	Robert Minsk <egbert@centropolisfx.com>
" Last Change:	May 27 1999
" Based on:	Bram Moolenaar <Bram@vim.org> C syntax file

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" when wanted, highlight trailing white space and spaces before tabs
if exists("mel_space_errors")
  sy match	melSpaceError	"\s\+$"
  sy match	melSpaceError	" \+\t"me=e-1
endif

" A bunch of useful MEL keywords
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
" Only when an item doesn't have highlighting yet

hi def link melBoolean	Boolean
hi def link melFunction	Function
hi def link melIdentifier	Identifier
hi def link melStatement	Statement
hi def link melConditional Conditional
hi def link melRepeat	Repeat
hi def link melLabel	Label
hi def link melOperator	Operator
hi def link melKeyword	Keyword
hi def link melException	Exception
hi def link melInclude	Include
hi def link melType	Type
hi def link melStorageClass StorageClass
hi def link melDebug	Debug
hi def link melTodo	Todo
hi def link melCharSpecial SpecialChar
hi def link melString	String
hi def link melInteger	Number
hi def link melFloat	Float
hi def link melMatrixVector Float
hi def link melComment	Comment
hi def link melError	Error
hi def link melSpaceError	melError
hi def link melCharError	melError
hi def link melParenError	melError
hi def link melInParen	melError
hi def link melCommentError melError


let b:current_syntax = "mel"
