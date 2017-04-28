" Vim syntax file
" Language:	TADS
" Maintainer:	Amir Karger <karger@post.harvard.edu>
" $Date: 2004/06/13 19:28:45 $
" $Revision: 1.1 $
" Stolen from: Bram Moolenaar's C language file
" Newest version at: http://www.hec.utah.edu/~karger/vim/syntax/tads.vim
" History info at the bottom of the file

" TODO lots more keywords
" global, self, etc. are special *objects*, not functions. They should
" probably be a different color than the special functions
" Actually, should cvtstr etc. be functions?! (change tadsFunction)
" Make global etc. into Identifiers, since we don't have regular variables?

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" A bunch of useful keywords
syn keyword tadsStatement	goto break return continue pass
syn keyword tadsLabel		case default
syn keyword tadsConditional	if else switch
syn keyword tadsRepeat		while for do
syn keyword tadsStorageClass	local compoundWord formatstring specialWords
syn keyword tadsBoolean		nil true

" TADS keywords
syn keyword tadsKeyword		replace modify
syn keyword tadsKeyword		global self inherited
" builtin functions
syn keyword tadsKeyword		cvtstr cvtnum caps lower upper substr
syn keyword tadsKeyword		say length
syn keyword tadsKeyword		setit setscore
syn keyword tadsKeyword		datatype proptype
syn keyword tadsKeyword		car cdr
syn keyword tadsKeyword		defined isclass
syn keyword tadsKeyword		find firstobj nextobj
syn keyword tadsKeyword		getarg argcount
syn keyword tadsKeyword		input yorn askfile
syn keyword tadsKeyword		rand randomize
syn keyword tadsKeyword		restart restore quit save undo
syn keyword tadsException	abort exit exitobj

syn keyword tadsTodo contained	TODO FIXME XXX

" String and Character constants
" Highlight special characters (those which have a backslash) differently
syn match tadsSpecial contained	"\\."
syn region tadsDoubleString		start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=tadsSpecial,tadsEmbedded
syn region tadsSingleString		start=+'+ skip=+\\\\\|\\'+ end=+'+ contains=tadsSpecial
" Embedded expressions in strings
syn region tadsEmbedded contained       start="<<" end=">>" contains=tadsKeyword

" TADS doesn't have \xxx, right?
"syn match cSpecial contained	"\\[0-7][0-7][0-7]\=\|\\."
"syn match cSpecialCharacter	"'\\[0-7][0-7]'"
"syn match cSpecialCharacter	"'\\[0-7][0-7][0-7]'"

"catch errors caused by wrong parenthesis
"syn region cParen		transparent start='(' end=')' contains=ALLBUT,cParenError,cIncluded,cSpecial,cTodo,cUserCont,cUserLabel
"syn match cParenError		")"
"syn match cInParen contained	"[{}]"
syn region tadsBrace		transparent start='{' end='}' contains=ALLBUT,tadsBraceError,tadsIncluded,tadsSpecial,tadsTodo
syn match tadsBraceError		"}"

"integer number (TADS has no floating point numbers)
syn case ignore
syn match tadsNumber		"\<[0-9]\+\>"
"hex number
syn match tadsNumber		"\<0x[0-9a-f]\+\>"
syn match tadsIdentifier	"\<[a-z][a-z0-9_$]*\>"
syn case match
" flag an octal number with wrong digits
syn match tadsOctalError		"\<0[0-7]*[89]"

" Removed complicated c_comment_strings
syn region tadsComment		start="/\*" end="\*/" contains=tadsTodo
syn match tadsComment		"//.*" contains=tadsTodo
syntax match tadsCommentError	"\*/"

syn region tadsPreCondit	start="^\s*#\s*\(if\>\|ifdef\>\|ifndef\>\|elif\>\|else\>\|endif\>\)" skip="\\$" end="$" contains=tadsComment,tadsString,tadsNumber,tadsCommentError
syn region tadsIncluded contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match tadsIncluded contained "<[^>]*>"
syn match tadsInclude		"^\s*#\s*include\>\s*["<]" contains=tadsIncluded
syn region tadsDefine		start="^\s*#\s*\(define\>\|undef\>\)" skip="\\$" end="$" contains=ALLBUT,tadsPreCondit,tadsIncluded,tadsInclude,tadsDefine,tadsInBrace,tadsIdentifier

syn region tadsPreProc start="^\s*#\s*\(pragma\>\|line\>\|warning\>\|warn\>\|error\>\)" skip="\\$" end="$" contains=ALLBUT,tadsPreCondit,tadsIncluded,tadsInclude,tadsDefine,tadsInParen,tadsIdentifier

" Highlight User Labels
" TODO labels for gotos?
"syn region	cMulti		transparent start='?' end=':' contains=ALLBUT,cIncluded,cSpecial,cTodo,cUserCont,cUserLabel,cBitField
" Avoid matching foo::bar() in C++ by requiring that the next char is not ':'
"syn match	cUserCont	"^\s*\I\i*\s*:$" contains=cUserLabel
"syn match	cUserCont	";\s*\I\i*\s*:$" contains=cUserLabel
"syn match	cUserCont	"^\s*\I\i*\s*:[^:]" contains=cUserLabel
"syn match	cUserCont	";\s*\I\i*\s*:[^:]" contains=cUserLabel

"syn match	cUserLabel	"\I\i*" contained

" identifier: class-name [, class-name [...]] [property-list] ;
" Don't highlight comment in class def
syn match tadsClassDef		"\<class\>[^/]*" contains=tadsObjectDef,tadsClass
syn match tadsClass contained   "\<class\>"
syn match tadsObjectDef "\<[a-zA-Z][a-zA-Z0-9_$]*\s*:\s*[a-zA-Z0-9_$]\+\(\s*,\s*[a-zA-Z][a-zA-Z0-9_$]*\)*\(\s*;\)\="
syn keyword tadsFunction contained function
syn match tadsFunctionDef	 "\<[a-zA-Z][a-zA-Z0-9_$]*\s*:\s*function[^{]*" contains=tadsFunction
"syn region tadsObject		  transparent start = '[a-zA-Z][\i$]\s*:\s*' end=";" contains=tadsBrace,tadsObjectDef

" How far back do we go to find matching groups
if !exists("tads_minlines")
  let tads_minlines = 15
endif
exec "syn sync ccomment tadsComment minlines=" . tads_minlines
if !exists("tads_sync_dist")
  let tads_sync_dist = 100
endif
execute "syn sync maxlines=" . tads_sync_dist

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" The default methods for highlighting.  Can be overridden later
hi def link tadsFunctionDef Function
hi def link tadsFunction  Structure
hi def link tadsClass     Structure
hi def link tadsClassDef  Identifier
hi def link tadsObjectDef Identifier
" no highlight for tadsEmbedded, so it prints as normal text w/in the string

hi def link tadsOperator	Operator
hi def link tadsStructure	Structure
hi def link tadsTodo	Todo
hi def link tadsLabel	Label
hi def link tadsConditional	Conditional
hi def link tadsRepeat	Repeat
hi def link tadsException	Exception
hi def link tadsStatement	Statement
hi def link tadsStorageClass	StorageClass
hi def link tadsKeyWord   Keyword
hi def link tadsSpecial	SpecialChar
hi def link tadsNumber	Number
hi def link tadsBoolean	Boolean
hi def link tadsDoubleString	tadsString
hi def link tadsSingleString	tadsString

hi def link tadsOctalError	tadsError
hi def link tadsCommentError	tadsError
hi def link tadsBraceError	tadsError
hi def link tadsInBrace	tadsError
hi def link tadsError	Error

hi def link tadsInclude	Include
hi def link tadsPreProc	PreProc
hi def link tadsDefine	Macro
hi def link tadsIncluded	tadsString
hi def link tadsPreCondit	PreCondit

hi def link tadsString	String
hi def link tadsComment	Comment



let b:current_syntax = "tads"

" Changes:
" 11/18/99 Added a bunch of TADS functions, tadsException
" 10/22/99 Misspelled Moolenaar (sorry!), c_minlines to tads_minlines
"
" vim: ts=8
