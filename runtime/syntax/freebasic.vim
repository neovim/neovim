" Vim syntax file
" Language:    FreeBasic
" Maintainer:  Mark Manning <markem@airmail.net>
" Updated:     10/22/2006
"
" Description:
"
"	Based originally on the work done by Allan Kelly <Allan.Kelly@ed.ac.uk>
"	Updated by Mark Manning <markem@airmail.net>
"	Applied FreeBasic support to the already excellent support
"	for standard basic syntax (like QB).
"
"	First version based on Micro$soft QBASIC circa
"	1989, as documented in 'Learn BASIC Now' by
"	Halvorson&Rygmyr. Microsoft Press 1989.  This syntax file
"	not a complete implementation yet.  Send suggestions to
"	the maintainer.
"
"	Quit when a (custom) syntax file was already loaded (Taken from c.vim)
"
if exists("b:current_syntax")
  finish
endif
"
"	Be sure to turn on the "case ignore" since current versions
"	of freebasic support both upper as well as lowercase
"	letters. - MEM 10/1/2006
"
syn case ignore
"
"	This list of keywords is taken directly from the FreeBasic
"	user's guide as presented by the FreeBasic online site.
"
syn keyword	freebasicArrays			ERASE LBOUND REDIM PRESERVE UBOUND

syn keyword	freebasicBitManipulation	BIT BITRESET BITSET HIBYTE HIWORD LOBYTE LOWORD SHL SHR

syn keyword	freebasicCompilerSwitches	DEFBYTE DEFDBL DEFINT DEFLNG DEFLNGINT DEFSHORT DEFSNG DEFSTR
syn keyword	freebasicCompilerSwitches	DEFUBYTE DEFUINT DEFULNGINT DEFUSHORT
syn match	freebasicCompilerSwitches	"\<option\s+\(BASE\|BYVAL\|DYNAMIC\|ESCAPE\|EXPLICIT\|NOKEYWORD\)\>"
syn match	freebasicCompilerSwitches	"\<option\s+\(PRIVATE\|STATIC\)\>"

syn region	freebasicConditional		start="\son\s+" skip=".*" end="gosub"
syn region	freebasicConditional		start="\son\s+" skip=".*" end="goto"
syn match	freebasicConditional		"\<select\s+case\>"
syn keyword	freebasicConditional		if iif then case else elseif with

syn match	freebasicConsole		"\<open\s+\(CONS\|ERR\|PIPE\|SCRN\)\>"
syn keyword	freebasicConsole		BEEP CLS CSRLIN LOCATE PRINT POS SPC TAB VIEW WIDTH

syn keyword	freebasicDataTypes		BYTE AS DIM CONST DOUBLE ENUM INTEGER LONG LONGINT SHARED SHORT STRING
syn keyword	freebasicDataTypes		SINGLE TYPE UBYTE UINTEGER ULONGINT UNION UNSIGNED USHORT WSTRING ZSTRING

syn keyword	freebasicDateTime		DATE DATEADD DATEDIFF DATEPART DATESERIAL DATEVALUE DAY HOUR MINUTE
syn keyword	freebasicDateTime		MONTH MONTHNAME NOW SECOND SETDATE SETTIME TIME TIMESERIAL TIMEVALUE
syn keyword	freebasicDateTime		TIMER YEAR WEEKDAY WEEKDAYNAME

syn keyword	freebasicDebug			ASSERT STOP

syn keyword	freebasicErrorHandling		ERR ERL ERROR LOCAL RESUME
syn match	freebasicErrorHandling		"\<resume\s+next\>"
syn match	freebasicErrorHandling		"\<on\s+error\>"

syn match	freebasicFiles			"\<get\s+#\>"
syn match	freebasicFiles			"\<input\s+#\>"
syn match	freebasicFiles			"\<line\s+input\s+#\>"
syn match	freebasicFiles			"\<put\s+#\>"
syn keyword	freebasicFiles			ACCESS APPEND BINARY BLOAD BSAVE CLOSE EOF FREEFILE INPUT LOC
syn keyword	freebasicFiles			LOCK LOF OPEN OUTPUT RANDOM RESET SEEK UNLOCK WRITE

syn keyword	freebasicFunctions		ALIAS ANY BYREF BYVAL CALL CDECL CONSTRUCTOR DESTRUCTOR
syn keyword	freebasicFunctions		DECLARE FUNCTION LIB OVERLOAD PASCAL STATIC SUB STDCALL
syn keyword	freebasicFunctions		VA_ARG VA_FIRST VA_NEXT

syn match	freebasicGraphics		"\<palette\s+get\>"
syn keyword	freebasicGraphics		ALPHA CIRCLE CLS COLOR CUSTOM DRAW FLIP GET
syn keyword	freebasicGraphics		IMAGECREATE IMAGEDESTROY LINE PAINT PALETTE PCOPY PMAP POINT
syn keyword	freebasicGraphics		PRESET PSET PUT RGB RGBA SCREEN SCREENCOPY SCREENINFO SCREENLIST
syn keyword	freebasicGraphics		SCREENLOCK SCREENPTR SCREENRES SCREENSET SCREENSYNC SCREENUNLOCK
syn keyword	freebasicGraphics		TRANS USING VIEW WINDOW

syn match	freebasicHardware		"\<open\s+com\>"
syn keyword	freebasicHardware		INP OUT WAIT LPT LPOS LPRINT

syn keyword	freebasicLogical		AND EQV IMP OR NOT XOR

syn keyword	freebasicMath			ABS ACOS ASIN ATAN2 ATN COS EXP FIX INT LOG MOD RANDOMIZE
syn keyword	freebasicMath			RND SGN SIN SQR TAN

syn keyword	freebasicMemory			ALLOCATE CALLOCATE CLEAR DEALLOCATE FIELD FRE PEEK POKE REALLOCATE

syn keyword	freebasicMisc			ASM DATA LET TO READ RESTORE SIZEOF SWAP OFFSETOF

syn keyword	freebasicModularizing		CHAIN COMMON EXPORT EXTERN DYLIBFREE DYLIBLOAD DYLIBSYMBOL
syn keyword	freebasicModularizing		PRIVATE PUBLIC

syn keyword	freebasicMultithreading		MUTEXCREATE MUTEXDESTROY MUTEXLOCK MUTEXUNLOCK THREADCREATE THREADWAIT

syn keyword	freebasicShell			CHDIR DIR COMMAND ENVIRON EXEC EXEPATH KILL NAME MKDIR RMDIR RUN

syn keyword	freebasicEnviron		SHELL SYSTEM WINDOWTITLE POINTERS

syn keyword	freebasicLoops			FOR LOOP WHILE WEND DO CONTINUE STEP UNTIL next

syn match	freebasicInclude		"\<#\s*\(inclib\|include\)\>"
syn match	freebasicInclude		"\<\$\s*include\>"

syn keyword	freebasicPointer		PROCPTR PTR SADD STRPTR VARPTR

syn keyword	freebasicPredefined		__DATE__ __FB_DOS__ __FB_LINUX__ __FB_MAIN__ __FB_MIN_VERSION__
syn keyword	freebasicPredefined		__FB_SIGNATURE__ __FB_VERSION__ __FB_WIN32__ __FB_VER_MAJOR__
syn keyword	freebasicPredefined		__FB_VER_MINOR__ __FB_VER_PATCH__ __FILE__ __FUNCTION__
syn keyword	freebasicPredefined		__LINE__ __TIME__

syn match	freebasicPreProcessor		"\<^#\s*\(define\|undef\)\>"
syn match	freebasicPreProcessor		"\<^#\s*\(ifdef\|ifndef\|else\|elseif\|endif\|if\)\>"
syn match	freebasicPreProcessor		"\<#\s*error\>"
syn match	freebasicPreProcessor		"\<#\s*\(print\|dynamic\|static\)\>"
syn keyword	freebasicPreProcessor		DEFINED ONCE

syn keyword	freebasicProgramFlow		END EXIT GOSUB GOTO
syn keyword	freebasicProgramFlow		IS RETURN SCOPE SLEEP

syn keyword	freebasicString			INSTR LCASE LEFT LEN LSET LTRIM MID RIGHT RSET RTRIM
syn keyword	freebasicString			SPACE STRING TRIM UCASE ASC BIN CHR CVD CVI CVL CVLONGINT
syn keyword	freebasicString			CVS CVSHORT FORMAT HEX MKD MKI MKL MKLONGINT MKS MKSHORT
syn keyword	freebasicString			OCT STR VAL VALLNG VALINT VALUINT VALULNG

syn keyword	freebasicTypeCasting		CAST CBYTE CDBL CINT CLNG CLNGINT CPTR CSHORT CSIGN CSNG
syn keyword	freebasicTypeCasting		CUBYTE CUINT CULNGINT CUNSG CURDIR CUSHORT

syn match	freebasicUserInput		"\<line\s+input\>"
syn keyword	freebasicUserInput		GETJOYSTICK GETKEY GETMOUSE INKEY INPUT MULTIKEY SETMOUSE
"
"	Do the Basic variables names first.  This is because it
"	is the most inclusive of the tests.  Later on we change
"	this so the identifiers are split up into the various
"	types of identifiers like functions, basic commands and
"	such. MEM 9/9/2006
"
syn match	freebasicIdentifier		"\<[a-zA-Z_][a-zA-Z0-9_]*\>"
syn match	freebasicGenericFunction	"\<[a-zA-Z_][a-zA-Z0-9_]*\>\s*("me=e-1,he=e-1
"
"	Function list
"
syn keyword	freebasicTodo		contained TODO
"
"	Catch errors caused by wrong parenthesis
"
syn region	freebasicParen		transparent start='(' end=')' contains=ALLBUT,@freebasicParenGroup
syn match	freebasicParenError	")"
syn match	freebasicInParen	contained "[{}]"
syn cluster	freebasicParenGroup	contains=freebasicParenError,freebasicSpecial,freebasicTodo,freebasicUserCont,freebasicUserLabel,freebasicBitField
"
"	Integer number, or floating point number without a dot and with "f".
"
syn region	freebasicHex		start="&h" end="\W"
syn region	freebasicHexError	start="&h\x*[g-zG-Z]" end="\W"
syn match	freebasicInteger	"\<\d\+\(u\=l\=\|lu\|f\)\>"
"
"	Floating point number, with dot, optional exponent
"
syn match	freebasicFloat		"\<\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\=\>"
"
"	Floating point number, starting with a dot, optional exponent
"
syn match	freebasicFloat		"\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
"
"	Floating point number, without dot, with exponent
"
syn match	freebasicFloat		"\<\d\+e[-+]\=\d\+[fl]\=\>"
"
"	Hex number
"
syn case match
syn match	freebasicOctal		"\<0\o*\>"
syn match	freebasicOctalError	"\<0\o*[89]"
"
"	String and Character contstants
"
syn region	freebasicString		start='"' end='"' contains=freebasicSpecial,freebasicTodo
syn region	freebasicString		start="'" end="'" contains=freebasicSpecial,freebasicTodo
"
"	Comments
"
syn match	freebasicSpecial	contained "\\."
syn region	freebasicComment	start="^rem" end="$" contains=freebasicSpecial,freebasicTodo
syn region	freebasicComment	start=":\s*rem" end="$" contains=freebasicSpecial,freebasicTodo
syn region	freebasicComment	start="\s*'" end="$" contains=freebasicSpecial,freebasicTodo
syn region	freebasicComment	start="^'" end="$" contains=freebasicSpecial,freebasicTodo
"
"	Now do the comments and labels
"
syn match	freebasicLabel		"^\d"
syn match	freebasicLabel		"\<^\w+:\>"
syn region	freebasicLineNumber	start="^\d" end="\s"
"
"	Create the clusters
"
syn cluster	freebasicNumber		contains=freebasicHex,freebasicOctal,freebasicInteger,freebasicFloat
syn cluster	freebasicError		contains=freebasicHexError,freebasicOctalError
"
"	Used with OPEN statement
"
syn match	freebasicFilenumber	"#\d\+"
syn match	freebasicMathOperator	"[\+\-\=\|\*\/\>\<\%\()[\]]" contains=freebasicParen
"
"	The default methods for highlighting.  Can be overridden later
"
hi def link freebasicArrays		StorageClass
hi def link freebasicBitManipulation	Operator
hi def link freebasicCompilerSwitches	PreCondit
hi def link freebasicConsole		Special
hi def link freebasicDataTypes		Type
hi def link freebasicDateTime		Type
hi def link freebasicDebug		Special
hi def link freebasicErrorHandling	Special
hi def link freebasicFiles		Special
hi def link freebasicFunctions		Function
hi def link freebasicGraphics		Function
hi def link freebasicHardware		Special
hi def link freebasicLogical		Conditional
hi def link freebasicMath		Function
hi def link freebasicMemory		Function
hi def link freebasicMisc		Special
hi def link freebasicModularizing	Special
hi def link freebasicMultithreading	Special
hi def link freebasicShell		Special
hi def link freebasicEnviron		Special
hi def link freebasicPointer		Special
hi def link freebasicPredefined		PreProc
hi def link freebasicPreProcessor	PreProc
hi def link freebasicProgramFlow	Statement
hi def link freebasicString		String
hi def link freebasicTypeCasting	Type
hi def link freebasicUserInput		Statement
hi def link freebasicComment		Comment
hi def link freebasicConditional	Conditional
hi def link freebasicError		Error
hi def link freebasicIdentifier		Identifier
hi def link freebasicInclude		Include
hi def link freebasicGenericFunction	Function
hi def link freebasicLabel		Label
hi def link freebasicLineNumber		Label
hi def link freebasicMathOperator	Operator
hi def link freebasicNumber		Number
hi def link freebasicSpecial		Special
hi def link freebasicTodo		Todo

let b:current_syntax = "freebasic"

" vim: ts=8
