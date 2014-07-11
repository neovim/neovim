" Vim syntax file
" Language:	CHILL
" Maintainer:	YoungSang Yoon <image@lgic.co.kr>
" Last change:	2004 Jan 21
"

" first created by image@lgic.co.kr & modified by paris@lgic.co.kr

" CHILL (CCITT High Level Programming Language) is used for
" developing software of ATM switch at LGIC (LG Information
" & Communications LTd.)


" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
syn keyword	chillSignal	RECEIVE receive SEND send NONPERSISTENT nonpersistent PERSISTENT peristent SET set EVER ever

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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_ch_syntax_inits")
  if version < 508
    let did_ch_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink chillLabel	Label
  HiLink chillUserLabel	Label
  HiLink chillConditional	Conditional
  " hi chillConditional	term=bold ctermfg=red guifg=red gui=bold

  HiLink chillRepeat	Repeat
  HiLink chillProcess	Repeat
  HiLink chillSignal	Repeat
  HiLink chillCharacter	Character
  HiLink chillSpecialCharacter chillSpecial
  HiLink chillNumber	Number
  HiLink chillFloat	Float
  HiLink chillOctalError	chillError
  HiLink chillParenError	chillError
  HiLink chillInParen	chillError
  HiLink chillCommentError	chillError
  HiLink chillSpaceError	chillError
  HiLink chillOperator	Operator
  HiLink chillStructure	Structure
  HiLink chillBlock	Operator
  HiLink chillScope	Operator
  "hi chillEDML     term=underline ctermfg=DarkRed guifg=Red
  HiLink chillEDML	PreProc
  "hi chillBoolConst	term=bold ctermfg=brown guifg=brown
  HiLink chillBoolConst	Constant
  "hi chillLogical	term=bold ctermfg=brown guifg=brown
  HiLink chillLogical	Constant
  HiLink chillStorageClass	StorageClass
  HiLink chillInclude	Include
  HiLink chillPreProc	PreProc
  HiLink chillDefine	Macro
  HiLink chillIncluded	chillString
  HiLink chillError	Error
  HiLink chillStatement	Statement
  HiLink chillPreCondit	PreCondit
  HiLink chillType	Type
  HiLink chillCommentError	chillError
  HiLink chillCommentString chillString
  HiLink chillComment2String chillString
  HiLink chillCommentSkip	chillComment
  HiLink chillString	String
  HiLink chillComment	Comment
  " hi chillComment	term=None ctermfg=lightblue guifg=lightblue
  HiLink chillSpecial	SpecialChar
  HiLink chillTodo	Todo
  HiLink chillBlock	Statement
  "HiLink chillIdentifier	Identifier
  HiLink chillBracket	Delimiter

  delcommand HiLink
endif

let b:current_syntax = "chill"

" vim: ts=8
