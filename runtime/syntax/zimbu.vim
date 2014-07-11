" Vim syntax file
" Language:	Zimbu
" Maintainer:	Bram Moolenaar
" Last Change:	2012 Jun 01

if exists("b:current_syntax")
  finish
endif

syn include @Ccode syntax/c.vim

syn keyword zimbuTodo		TODO FIXME XXX contained
syn match   zimbuNoBar          "|" contained
syn match   zimbuParam  	"|[^| ]\+|" contained contains=zimbuNoBar
syn match   zimbuComment	"#.*$" contains=zimbuTodo,zimbuParam,@Spell

syn match   zimbuChar	"'\\\=.'"

syn keyword zimbuBasicType	bool status
syn keyword zimbuBasicType	int1 int2 int3 int4 int5 int6 int7
syn keyword zimbuBasicType	int9 int10 int11 int12 int13 int14 int15
syn keyword zimbuBasicType	int int8 int16 int32 int64 bigInt
syn keyword zimbuBasicType	nat nat8 byte nat16 nat32 nat64 bigNat
syn keyword zimbuBasicType	nat1 nat2 nat3 nat4 nat5 nat6 nat7
syn keyword zimbuBasicType	nat9 nat10 nat11 nat12 nat13 nat14 nat15
syn keyword zimbuBasicType	float float32 float64 float80 float128
syn keyword zimbuBasicType	fixed1 fixed2 fixed3 fixed4 fixed5 fixed6
syn keyword zimbuBasicType	fixed7 fixed8 fixed9 fixed10 fixed11 fixed12
syn keyword zimbuBasicType	fixed13 fixed14 fixed15

syn keyword zimbuCompType	string stringval cstring varstring
syn keyword zimbuCompType	bytes varbytes
syn keyword zimbuCompType	tuple array list dict multiDict set multiSet
syn keyword zimbuCompType	complex complex32 complex64 complex80 complex128
syn keyword zimbuCompType	proc func def thread evalThread lock cond pipe

syn keyword zimbuType   VAR ANY USE GET
syn match zimbuType	"IO.File"
syn match zimbuType	"IO.Stat"

syn keyword zimbuStatement IF ELSE ELSEIF WHILE REPEAT FOR IN TO STEP
syn keyword zimbuStatement DO UNTIL SWITCH WITH
syn keyword zimbuStatement TRY CATCH FINALLY
syn keyword zimbuStatement GENERATE_IF GENERATE_ELSE GENERATE_ELSEIF
syn keyword zimbuStatement CASE DEFAULT FINAL ABSTRACT VIRTUAL DEFINE REPLACE
syn keyword zimbuStatement IMPLEMENTS EXTENDS PARENT LOCAL
syn keyword zimbuStatement PART ALIAS CONNECT WRAP
syn keyword zimbuStatement BREAK CONTINUE PROCEED
syn keyword zimbuStatement RETURN EXIT THROW
syn keyword zimbuStatement IMPORT AS OPTIONS MAIN
syn keyword zimbuStatement INTERFACE MODULE ENUM BITS SHARED
syn match zimbuStatement "\<\(FUNC\|PROC\|DEF\)\>"
syn match zimbuStatement "\<CLASS\>"
syn match zimbuStatement "}"

syn match zimbuAttribute "@backtrace=no\>"
syn match zimbuAttribute "@backtrace=yes\>"
syn match zimbuAttribute "@abstract\>"
syn match zimbuAttribute "@earlyInit\>"
syn match zimbuAttribute "@default\>"
syn match zimbuAttribute "@define\>"
syn match zimbuAttribute "@replace\>"
syn match zimbuAttribute "@final\>"

syn match zimbuAttribute "@private\>"
syn match zimbuAttribute "@protected\>"
syn match zimbuAttribute "@public\>"
syn match zimbuAttribute "@file\>"
syn match zimbuAttribute "@directory\>"
syn match zimbuAttribute "@read=private\>"
syn match zimbuAttribute "@read=protected\>"
syn match zimbuAttribute "@read=public\>"
syn match zimbuAttribute "@read=file\>"
syn match zimbuAttribute "@read=directory\>"
syn match zimbuAttribute "@items=private\>"
syn match zimbuAttribute "@items=protected\>"
syn match zimbuAttribute "@items=public\>"
syn match zimbuAttribute "@items=file\>"
syn match zimbuAttribute "@items=directory\>"

syn keyword zimbuMethod NEW EQUAL COPY COMPARE SIZE GET SET

syn keyword zimbuOperator IS ISNOT ISA ISNOTA

syn keyword zimbuModule  ARG CHECK E IO PROTO SYS HTTP ZC ZWT TIME THREAD

syn match zimbuString  +"\([^"\\]\|\\.\)*\("\|$\)+
syn match zimbuString  +R"\([^"]\|""\)*\("\|$\)+
syn region zimbuString  start=+'''+ end=+'''+

syn keyword zimbuFixed  TRUE FALSE NIL THIS THISTYPE FAIL OK
syn keyword zimbuError  NULL

" trailing whitespace
syn match   zimbuSpaceError   display excludenl "\S\s\+$"ms=s+1
" mixed tabs and spaces
syn match   zimbuSpaceError   display " \+\t"
syn match   zimbuSpaceError   display "\t\+ "

syn match zimbuUses contained "uses([a-zA-Z_ ,]*)"
syn match zimbuBlockComment contained " #.*"

syn region zimbuCregion matchgroup=zimbuCblock start="^>>>" end="^<<<.*" contains=@Ccode,zimbuUses,zimbuBlockComment keepend

syn sync minlines=2000

hi def link zimbuBasicType	Type
hi def link zimbuCompType	Type
hi def link zimbuType		Type
hi def link zimbuStatement	Statement
hi def link zimbuOperator	Statement
hi def link zimbuMethod		PreProc
hi def link zimbuModule		PreProc
hi def link zimbuUses		PreProc
hi def link zimbuAttribute	PreProc
hi def link zimbuString		Constant
hi def link zimbuChar		Constant
hi def link zimbuFixed		Constant
hi def link zimbuComment	Comment
hi def link zimbuBlockComment	Comment
hi def link zimbuCblock		Comment
hi def link zimbuTodo		Todo
hi def link zimbuParam		Constant
hi def link zimbuNoBar		Ignore
hi def link zimbuSpaceError	Error
hi def link zimbuError		Error

let b:current_syntax = "zimbu"

" vim: ts=8
