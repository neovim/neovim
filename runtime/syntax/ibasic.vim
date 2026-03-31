" Vim syntax file
" Language:	ibasic
" Maintainer:	Mark Manning <markem@airmail.net>
" Originator:	Allan Kelly <Allan.Kelly@ed.ac.uk>
" Created:	10/1/2006
" Updated:	10/21/2006
" Description:  A vim file to handle the IBasic file format.
" Notes:
"	Updated by Mark Manning <markem@airmail.net>
"	Applied IBasic support to the already excellent support for standard
"	basic syntax (like QB).
"
"	First version based on Micro$soft QBASIC circa 1989, as documented in
"	'Learn BASIC Now' by Halvorson&Rygmyr. Microsoft Press 1989.
"	This syntax file not a complete implementation yet.
"	Send suggestions to the maintainer.
"
"	This version is based upon the commands found in IBasic (www.pyxia.com).
"	MEM 10/6/2006
"
"	Quit when a (custom) syntax file was already loaded (Taken from c.vim)
"
if exists("b:current_syntax")
  finish
endif
"
"	Be sure to turn on the "case ignore" since current versions of basic
"	support both upper as well as lowercase letters.
"
syn case ignore
"
" A bunch of useful BASIC keywords
"
syn keyword ibasicStatement	beep bload bsave call absolute chain chdir circle
syn keyword ibasicStatement	clear close cls color com common const data
syn keyword ibasicStatement	loop draw end environ erase error exit field
syn keyword ibasicStatement	files function get gosub goto
syn keyword ibasicStatement	input input# ioctl key kill let line locate
syn keyword ibasicStatement	lock unlock lprint using lset mkdir name
syn keyword ibasicStatement	on error open option base out paint palette pcopy
syn keyword ibasicStatement	pen play pmap poke preset print print# using pset
syn keyword ibasicStatement	put randomize read redim reset restore resume
syn keyword ibasicStatement	return rmdir rset run seek screen
syn keyword ibasicStatement	shared shell sleep sound static stop strig sub
syn keyword ibasicStatement	swap system timer troff tron type unlock
syn keyword ibasicStatement	view wait width window write
syn keyword ibasicStatement	date$ mid$ time$
"
"	Do the basic variables names first.  This is because it
"	is the most inclusive of the tests.  Later on we change
"	this so the identifiers are split up into the various
"	types of identifiers like functions, basic commands and
"	such. MEM 9/9/2006
"
syn match	ibasicIdentifier			"\<[a-zA-Z_][a-zA-Z0-9_]*\>"
syn match	ibasicGenericFunction	"\<[a-zA-Z_][a-zA-Z0-9_]*\>\s*("me=e-1,he=e-1
"
"	Function list
"
syn keyword ibasicBuiltInFunction	abs asc atn cdbl cint clng cos csng csrlin cvd cvdmbf
syn keyword ibasicBuiltInFunction	cvi cvl cvs cvsmbf eof erdev erl err exp fileattr
syn keyword ibasicBuiltInFunction	fix fre freefile inp instr lbound len loc lof
syn keyword ibasicBuiltInFunction	log lpos mod peek pen point pos rnd sadd screen seek
syn keyword ibasicBuiltInFunction	setmem sgn sin spc sqr stick strig tab tan ubound
syn keyword ibasicBuiltInFunction	val valptr valseg varptr varseg
syn keyword ibasicBuiltInFunction	chr\$ command$ date$ environ$ erdev$ hex$ inkey$
syn keyword ibasicBuiltInFunction	input$ ioctl$ lcases$ laft$ ltrim$ mid$ mkdmbf$ mkd$
syn keyword ibasicBuiltInFunction	mki$ mkl$ mksmbf$ mks$ oct$ right$ rtrim$ space$
syn keyword ibasicBuiltInFunction	str$ string$ time$ ucase$ varptr$
syn keyword ibasicTodo contained	TODO
syn cluster	ibasicFunctionCluster	contains=ibasicBuiltInFunction,ibasicGenericFunction

syn keyword Conditional	if else then elseif endif select case endselect
syn keyword Repeat	for do while next enddo endwhile wend

syn keyword ibasicTypeSpecifier	single double defdbl defsng
syn keyword ibasicTypeSpecifier	int integer uint uinteger int64 uint64 defint deflng
syn keyword ibasicTypeSpecifier	byte char string istring defstr
syn keyword ibasicDefine	dim def declare
"
"catch errors caused by wrong parenthesis
"
syn cluster	ibasicParenGroup	contains=ibasicParenError,ibasicIncluded,ibasicSpecial,ibasicTodo,ibasicUserCont,ibasicUserLabel,ibasicBitField
syn region	ibasicParen		transparent start='(' end=')' contains=ALLBUT,@bParenGroup
syn match	ibasicParenError	")"
syn match	ibasicInParen	contained "[{}]"
"
"integer number, or floating point number without a dot and with "f".
"
syn region	ibasicHex		start="&h" end="\W"
syn region	ibasicHexError	start="&h\x*[g-zG-Z]" end="\W"
syn match	ibasicInteger	"\<\d\+\(u\=l\=\|lu\|f\)\>"
"
"floating point number, with dot, optional exponent
"
syn match	ibasicFloat		"\<\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\=\>"
"
"floating point number, starting with a dot, optional exponent
"
syn match	ibasicFloat		"\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
"
"floating point number, without dot, with exponent
"
syn match	ibasicFloat		"\<\d\+e[-+]\=\d\+[fl]\=\>"
"
"hex number
"
syn match	ibasicIdentifier	"\<[a-zA-Z_][a-zA-Z0-9_]*\>"
syn match	ibasicFunction	"\<[a-zA-Z_][a-zA-Z0-9_]*\>\s*("me=e-1,he=e-1
syn case match
syn match	ibasicOctalError	"\<0\o*[89]"
"
" String and Character contstants
"
syn region	ibasicString		start='"' end='"' contains=ibasicSpecial,ibasicTodo
syn region	ibasicString		start="'" end="'" contains=ibasicSpecial,ibasicTodo
"
"	Comments
"
syn match	ibasicSpecial	contained "\\."
syn region  ibasicComment	start="^rem" end="$" contains=ibasicSpecial,ibasicTodo
syn region  ibasicComment	start=":\s*rem" end="$" contains=ibasicSpecial,ibasicTodo
syn region	ibasicComment	start="\s*'" end="$" contains=ibasicSpecial,ibasicTodo
syn region	ibasicComment	start="^'" end="$" contains=ibasicSpecial,ibasicTodo
"
"	Now do the comments and labels
"
syn match	ibasicLabel		"^\d"
syn region  ibasicLineNumber	start="^\d" end="\s"
"
"	Pre-compiler options : FreeBasic
"
syn region	ibasicPreCondit	start="^\s*#\s*\(if\>\|ifdef\>\|ifndef\>\|elif\>\|else\>\|endif\>\)" skip="\\$" end="$" contains=ibasicString,ibasicCharacter,ibasicNumber,ibasicCommentError,ibasicSpaceError
syn match	ibasicInclude	"^\s*#\s*include\s*"
"
"	Create the clusters
"
syn cluster ibasicNumber contains=ibasicHex,ibasicInteger,ibasicFloat
syn cluster	ibasicError	contains=ibasicHexError
"
"	Used with OPEN statement
"
syn match   ibasicFilenumber  "#\d\+"
"
"syn sync ccomment ibasicComment
"
syn match	ibasicMathOperator	"[\+\-\=\|\*\/\>\<\%\()[\]]" contains=ibasicParen
"
" The default methods for highlighting.  Can be overridden later
"
hi def link ibasicLabel			Label
hi def link ibasicConditional		Conditional
hi def link ibasicRepeat		Repeat
hi def link ibasicHex			Number
hi def link ibasicInteger		Number
hi def link ibasicFloat			Number
hi def link ibasicError			Error
hi def link ibasicHexError		Error
hi def link ibasicStatement		Statement
hi def link ibasicString		String
hi def link ibasicComment		Comment
hi def link ibasicLineNumber		Comment
hi def link ibasicSpecial		Special
hi def link ibasicTodo			Todo
hi def link ibasicGenericFunction	Function
hi def link ibasicBuiltInFunction	Function
hi def link ibasicTypeSpecifier		Type
hi def link ibasicDefine		Type
hi def link ibasicInclude		Include
hi def link ibasicIdentifier		Identifier
hi def link ibasicFilenumber		ibasicTypeSpecifier
hi def link ibasicMathOperator		Operator

let b:current_syntax = "ibasic"

" vim: ts=8
