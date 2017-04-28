" Vim syntax file
" Language:	CHILL
" Maintainer:	YoungSang Yoon <image@lgic.co.kr>
" Last change:	2004 Jan 21
"

" first created by image@lgic.co.kr & modified by paris@lgic.co.kr

" CHILL (CCITT High Level Programming Language) is used for
" developing software of ATM switch at LGIC (LG Information
" & Communications LTd.)


" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" A bunch of useful CHILL keywords
syn keyword	chillStatement	goto GOTO return RETURN returns RETURNS
syn keyword	chillLabel		CASE case ESAC esac
syn keyword	chillConditional	if IF else ELSE elsif ELSIF switch SWITCH THEN then FI fi
syn keyword	chillLogical	NOT not
syn keyword	chillRepeat	while WHILE for FOR do DO od OD TO to
syn keyword	chillProcess	START start STACKSIZE stacksize PRIORITY priority THIS this STOP stop
syn keyword	chillBlock		PROC proc PROCESS process
syn keyword	chillSignal	RECEIVE receive SEND send NONPERSISTENT nonpersistent PERSISTENT persistent SET set EVER ever

syn keyword	chillTodo		contained TODO FIXME XXX

" String and Character constants
" Highlight special characters (those which have a backslash) differently
syn match	chillSpecial	contained "\\x\x\+\|\\\o\{1,3\}\|\\.\|\\$"
syn region	chillString	start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=chillSpecial
syn match	chillCharacter	"'[^\\]'"
syn match	chillSpecialCharacter "'\\.'"
syn match	chillSpecialCharacter "'\\\o\{1,3\}'"

"when wanted, highlight trailing white space
if exists("chill_space_errors")
  syn match	chillSpaceError	"\s*$"
  syn match	chillSpaceError	" \+\t"me=e-1
endif

"catch errors caused by wrong parenthesis
syn cluster	chillParenGroup	contains=chillParenError,chillIncluded,chillSpecial,chillTodo,chillUserCont,chillUserLabel,chillBitField
syn region	chillParen		transparent start='(' end=')' contains=ALLBUT,@chillParenGroup
syn match	chillParenError	")"
syn match	chillInParen	contained "[{}]"

"integer number, or floating point number without a dot and with "f".
syn case ignore
syn match	chillNumber		"\<\d\+\(u\=l\=\|lu\|f\)\>"
"floating point number, with dot, optional exponent
syn match	chillFloat		"\<\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, starting with a dot, optional exponent
syn match	chillFloat		"\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, without dot, with exponent
syn match	chillFloat		"\<\d\+e[-+]\=\d\+[fl]\=\>"
"hex number
syn match	chillNumber		"\<0x\x\+\(u\=l\=\|lu\)\>"
"syn match chillIdentifier	"\<[a-z_][a-z0-9_]*\>"
syn case match
" flag an octal number with wrong digits
syn match	chillOctalError	"\<0\o*[89]"

if exists("chill_comment_strings")
  " A comment can contain chillString, chillCharacter and chillNumber.
  " But a "*/" inside a chillString in a chillComment DOES end the comment!  So we
  " need to use a special type of chillString: chillCommentString, which also ends on
  " "*/", and sees a "*" at the start of the line as comment again.
  " Unfortunately this doesn't very well work for // type of comments :-(
  syntax match	chillCommentSkip	contained "^\s*\*\($\|\s\+\)"
  syntax region chillCommentString	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ end=+\*/+me=s-1 contains=chillSpecial,chillCommentSkip
  syntax region chillComment2String	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ end="$" contains=chillSpecial
  syntax region chillComment	start="/\*" end="\*/" contains=chillTodo,chillCommentString,chillCharacter,chillNumber,chillFloat,chillSpaceError
  syntax match  chillComment	"//.*" contains=chillTodo,chillComment2String,chillCharacter,chillNumber,chillSpaceError
else
  syn region	chillComment	start="/\*" end="\*/" contains=chillTodo,chillSpaceError
  syn match	chillComment	"//.*" contains=chillTodo,chillSpaceError
endif
syntax match	chillCommentError	"\*/"

syn keyword	chillOperator	SIZE size
syn keyword	chillType		dcl DCL int INT char CHAR bool BOOL REF ref LOC loc INSTANCE instance
syn keyword	chillStructure	struct STRUCT enum ENUM newmode NEWMODE synmode SYNMODE
"syn keyword	chillStorageClass
syn keyword	chillBlock		PROC proc END end
syn keyword	chillScope		GRANT grant SEIZE seize
syn keyword	chillEDML		select SELECT delete DELETE update UPDATE in IN seq SEQ WHERE where INSERT insert include INCLUDE exclude EXCLUDE
syn keyword	chillBoolConst	true TRUE false FALSE

syn region	chillPreCondit	start="^\s*#\s*\(if\>\|ifdef\>\|ifndef\>\|elif\>\|else\>\|endif\>\)" skip="\\$" end="$" contains=chillComment,chillString,chillCharacter,chillNumber,chillCommentError,chillSpaceError
syn region	chillIncluded	contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match	chillIncluded	contained "<[^>]*>"
syn match	chillInclude	"^\s*#\s*include\>\s*["<]" contains=chillIncluded
"syn match chillLineSkip	"\\$"
syn cluster	chillPreProcGroup	contains=chillPreCondit,chillIncluded,chillInclude,chillDefine,chillInParen,chillUserLabel
syn region	chillDefine		start="^\s*#\s*\(define\>\|undef\>\)" skip="\\$" end="$" contains=ALLBUT,@chillPreProcGroup
syn region	chillPreProc	start="^\s*#\s*\(pragma\>\|line\>\|warning\>\|warn\>\|error\>\)" skip="\\$" end="$" contains=ALLBUT,@chillPreProcGroup

" Highlight User Labels
syn cluster	chillMultiGroup	contains=chillIncluded,chillSpecial,chillTodo,chillUserCont,chillUserLabel,chillBitField
syn region	chillMulti		transparent start='?' end=':' contains=ALLBUT,@chillMultiGroup
" Avoid matching foo::bar() in C++ by requiring that the next char is not ':'
syn match	chillUserCont	"^\s*\I\i*\s*:$" contains=chillUserLabel
syn match	chillUserCont	";\s*\I\i*\s*:$" contains=chillUserLabel
syn match	chillUserCont	"^\s*\I\i*\s*:[^:]"me=e-1 contains=chillUserLabel
syn match	chillUserCont	";\s*\I\i*\s*:[^:]"me=e-1 contains=chillUserLabel

syn match	chillUserLabel	"\I\i*" contained

" Avoid recognizing most bitfields as labels
syn match	chillBitField	"^\s*\I\i*\s*:\s*[1-9]"me=e-1
syn match	chillBitField	";\s*\I\i*\s*:\s*[1-9]"me=e-1

syn match	chillBracket	contained "[<>]"
if !exists("chill_minlines")
  let chill_minlines = 15
endif
exec "syn sync ccomment chillComment minlines=" . chill_minlines

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link chillLabel	Label
hi def link chillUserLabel	Label
hi def link chillConditional	Conditional
" hi def link chillConditional	term=bold ctermfg=red guifg=red gui=bold

hi def link chillRepeat	Repeat
hi def link chillProcess	Repeat
hi def link chillSignal	Repeat
hi def link chillCharacter	Character
hi def link chillSpecialCharacter chillSpecial
hi def link chillNumber	Number
hi def link chillFloat	Float
hi def link chillOctalError	chillError
hi def link chillParenError	chillError
hi def link chillInParen	chillError
hi def link chillCommentError	chillError
hi def link chillSpaceError	chillError
hi def link chillOperator	Operator
hi def link chillStructure	Structure
hi def link chillBlock	Operator
hi def link chillScope	Operator
"hi def link chillEDML     term=underline ctermfg=DarkRed guifg=Red
hi def link chillEDML	PreProc
"hi def link chillBoolConst	term=bold ctermfg=brown guifg=brown
hi def link chillBoolConst	Constant
"hi def link chillLogical	term=bold ctermfg=brown guifg=brown
hi def link chillLogical	Constant
hi def link chillStorageClass	StorageClass
hi def link chillInclude	Include
hi def link chillPreProc	PreProc
hi def link chillDefine	Macro
hi def link chillIncluded	chillString
hi def link chillError	Error
hi def link chillStatement	Statement
hi def link chillPreCondit	PreCondit
hi def link chillType	Type
hi def link chillCommentError	chillError
hi def link chillCommentString chillString
hi def link chillComment2String chillString
hi def link chillCommentSkip	chillComment
hi def link chillString	String
hi def link chillComment	Comment
" hi def link chillComment	term=None ctermfg=lightblue guifg=lightblue
hi def link chillSpecial	SpecialChar
hi def link chillTodo	Todo
hi def link chillBlock	Statement
"hi def link chillIdentifier	Identifier
hi def link chillBracket	Delimiter


let b:current_syntax = "chill"

" vim: ts=8
