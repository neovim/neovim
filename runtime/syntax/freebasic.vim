" Vim syntax file
" Language:		FreeBASIC
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Mark Manning <markem@sim1.us>
" Last Change:		2023 Aug 14
"
" Description:
"
"	Based originally on the work done by Allan Kelly <Allan.Kelly@ed.ac.uk>
"	Updated by Mark Manning <markem@sim1.us>
"	Applied FreeBASIC support to the already excellent support
"	for standard basic syntax (like QB).
"
"	First version based on Micro$soft QBASIC circa
"	1989, as documented in 'Learn BASIC Now' by
"	Halvorson&Rygmyr. Microsoft Press 1989.  This syntax file
"	not a complete implementation yet.  Send suggestions to
"	the maintainer.
"
"	TODO: split this into separate dialect-based files, possibly with a common base
"
"	Quit when a (custom) syntax file was already loaded (Taken from c.vim)
"
if exists("b:current_syntax")
  finish
endif
"
"	Dialect detection
"
let s:lang = freebasic#GetDialect()
"
"	Whitespace Errors
"
if exists("freebasic_space_errors")
  if !exists("freebasic_no_trail_space_error")
    syn match freebasicSpaceError display excludenl "\s\+$"
  endif
  if !exists("freebasic_no_tab_space_error")
    syn match freebasicSpaceError display " \+\t"me=e-1
  endif
endif
"
"	Be sure to turn on the "case ignore" since current versions
"	of freebasic support both upper as well as lowercase
"	letters. - MEM 10/1/2006
"
syn case ignore
"
"	Do the Basic variables names first.  This is because it
"	is the most inclusive of the tests.  Later on we change
"	this so the identifiers are split up into the various
"	types of identifiers like functions, basic commands and
"	such. MEM 9/9/2006
"
if s:lang =~# '\<\%(qb\|fblite\)\>'
  syn iskeyword @,48-57,_,192-255,.
  syn match	freebasicIdentifier		"\<\h\%(\w\|\.\)*\>"
  syn match	freebasicGenericFunction	"\<\h\%(\w\|\.\)*\>\ze\s*("
else
  syn iskeyword @,48-57,_,192-255
  syn match	freebasicIdentifier		"\<\h\w*\>"
  syn match	freebasicGenericFunction	"\<\h\w*\>\ze\s*("
endif
"
"	This list of keywords is taken directly from the FreeBASIC
"	user's guide as presented by the FreeBASIC online site.
"
syn keyword	freebasicArrays			ERASE LBOUND PRESERVE REDIM UBOUND

" array.bi
syn keyword	freebasicArrays			ARRAYLEN ARRAYSIZE
if s:lang == "fb"
  syn keyword	freebasicArrays			ArrayConstDescriptorPtr ArrayDescriptorPtr FBARRAY
endif

if s:lang == "qb"
  syn keyword	freebasicAsm			__ASM
  syn match	freebasicAsm			"\<end\s\+__asm\>"
else
  syn keyword	freebasicAsm			ASM
  syn match	freebasicAsm			"\<end\s\+asm\>"
endif

if s:lang == "qb"
  syn keyword	freebasicBitManipulation	__BIT __BITRESET __BITSET __HIBYTE __HIWORD __LOBYTE __LOWORD
else
  syn keyword	freebasicBitManipulation	BIT BITRESET BITSET HIBYTE HIWORD LOBYTE LOWORD
endif

if s:lang != "fb"
  syn keyword	freebasicCompilerSwitches	DEFDBL DEFINT DEFLNG DEFSNG DEFSTR
endif
if s:lang == "qb"
  syn keyword	freebasicCompilerSwitches	__DEFBYTE __DEFLONGINT __DEFSHORT __DEFUBYTE __DEFUINT __DEFULONGINT __DEFUSHORT
elseif s:lang == "fblite" || s:lang == "deprecated"
  syn keyword	freebasicCompilerSwitches	DEFBYTE DEFLONGINT DEFSHORT DEFUBYTE DEFUINT DEFUILONGINT DEFUSHORT
endif

syn match	freebasicCompilerSwitches	"\<option\s\+\%(BASE\|BYVAL\|DYNAMIC\|ESCAPE\|EXPLICIT\|GOSUB\|NOGOSUB\)\>"
syn match	freebasicCompilerSwitches	"\<option\s\+\%(NOKEYWORD\|PRIVATE\|STATIC\)\>"

syn keyword	freebasicData			DATA READ RESTORE

syn keyword	freebasicProgramFlow		EXIT GOTO RETURN SLEEP
syn match	freebasicProgramFlow		"\<end\>"
if s:lang == "qb"
  syn keyword	freebasicProgramFlow		__SLEEP
endif
if s:lang == "fblite" || s:lang == "qb"
  syn keyword	freebasicProgramFlow		GOSUB
endif
if s:lang == "fb" || s:lang == "deprecated"
  syn keyword	freebasicProgramFlow		SCOPE
  syn match	freebasicProgramFlow		"\<end\s\+scope\>"
endif

if s:lang == "fblite" || s:lang == "qb"
  syn region	freebasicConditional		matchgroup=freebasicConditional start="\<on\>" end="\<gosub\>" transparent
  syn region	freebasicConditional		matchgroup=freebasicConditional start="\<on\>" end="\<goto\>"  transparent
endif
syn keyword	freebasicConditional		IF THEN ELSE ELSEIF
if s:lang == "qb"
  syn keyword	freebasicConditional		__IIF __WITH
  syn match	freebasicConditional		"\<end\s\+__with\>"
else
  syn keyword	freebasicConditional		IIF WITH
  syn match	freebasicConditional		"\<end\s\+with\>"
endif
syn match	freebasicConditional		"\<end\s\+if\>"
syn match	freebasicConditional		"\<select\s\+case\>"
syn match	freebasicConditional		"\<case\>"
syn match	freebasicConditional		"\<case\s\+is\>"
syn match	freebasicConditional		"\<end\s\+select\>"

syn keyword	freebasicConsole		BEEP CLS CSRLIN LOCATE PRINT POS SPC TAB USING VIEW WIDTH
syn match	freebasicConsole		"?"

syn keyword	freebasicDataTypes		SINGLE DOUBLE INTEGER LONG
syn match	freebasicDataTypes		"\<string\>"
syn keyword	freebasicDataTypes		AS DIM CONST ENUM SHARED TYPE
syn match	freebasicDataTypes		"\<end\s\+enum\>"
syn match	freebasicDataTypes		"\<end\s\+type\>"
if s:lang == "qb"
  syn keyword	freebasicDataTypes		__BOOLEAN __BYTE __LONGINT __SHORT __UBYTE __UINTEGER __ULONG __ULONGINT __UNSIGNED __USHORT __ZSTRING
  syn match	freebasicDataTypes		"\<__WSTRING\>"
  syn keyword	freebasicDataTypes		__EXPLICIT __EXTENDS __IMPLEMENTS __OBJECT __POINTER __PTR __SIZEOF __TYPEOF
  syn keyword	freebasicDataTypes		__UNION
  syn match	freebasicDataTypes		"\<end\s\+__union\>"
else
  syn keyword	freebasicDataTypes		BOOLEAN BYTE LONGINT SHORT UBYTE UINTEGER ULONG ULONGINT UNSIGNED USHORT ZSTRING
  syn match	freebasicDataTypes		"\<WSTRING\>"
  syn keyword	freebasicDataTypes		EXPLICIT EXTENDS IMPLEMENTS OBJECT POINTER PTR SIZEOF TYPEOF
  syn keyword	freebasicDataTypes		UNION
  syn match	freebasicDataTypes		"\<end\s\+union\>"
endif
if s:lang == "fb"
  syn keyword	freebasicDataTypes		BASE CLASS THIS VAR
endif

if s:lang == "qb"
  syn match	freebasicDateTime		"\<\%(date\|time\)\$"
elseif s:lang == "fblite" || s:lang == "deprecated"
  syn match	freebasicDateTime		"\<\%(date\|time\)\>\$\="
else " fb
  syn keyword	freebasicDateTime		DATE TIME
endif
syn keyword	freebasicDateTime		SETDATE SETTIME

" datetime.bi
syn keyword	freebasicDateTime		DATEADD DATEDIFF DATEPART DATESERIAL DATEVALUE DAY HOUR ISDATE MINUTE
syn keyword	freebasicDateTime		MONTH MONTHNAME NOW SECOND TIMESERIAL TIMEVALUE
syn keyword	freebasicDateTime		TIMER YEAR WEEKDAY WEEKDAYNAME

syn keyword	freebasicDebug			STOP
if s:lang == "qb"
  syn keyword	freebasicDebug			__ASSERT __ASSERTWARN
else
  syn keyword	freebasicDebug			ASSERT ASSERTWARN
endif

syn keyword	freebasicErrorHandling		ERR ERL ERROR
if s:lang == "qb"
  syn keyword	freebasicErrorHandling		__ERFN __ERMN
  syn match	freebasicErrorHandling		"\<on\s\+error\>"
else
  syn keyword	freebasicErrorHandling		ERFN ERMN
  syn match	freebasicErrorHandling		"\<on\s\+\%(local\s\+\)\=error\>"
endif
if s:lang != "fb"
  syn match	freebasicErrorHandling		"\<resume\%(\s\+next\)\=\>"
endif

syn match	freebasicFiles			"\<get\s\+#\>"
syn match	freebasicFiles			"\<input\s\+#\>"
syn match	freebasicFiles			"\<line\s\+input\s\+#\>"
syn match	freebasicFiles			"\<put\s\+#\>"
syn keyword	freebasicFiles			ACCESS APPEND BINARY CLOSE EOF FREEFILE INPUT LOC
syn keyword	freebasicFiles			LOCK LOF OUTPUT RANDOM RESET SEEK UNLOCK WRITE
syn match	freebasicFiles			"\<open\>"
if s:lang == "qb"
  syn keyword	freebasicFiles			__ENCODING
else
  syn keyword	freebasicFiles			ENCODING WINPUT
  syn match	freebasicFiles			"\<open\s\+\%(cons\|err\|pipe\|scrn\)\>"
endif

" file.bi
syn keyword	freebasicFiles			FILEATTR FILECOPY FILEDATETIME FILEEXISTS FILEFLUSH FILELEN FILESETEOF

syn keyword	freebasicFunctions		ALIAS BYREF BYVAL CDECL DECLARE LIB NAKED PASCAL STATIC STDCALL
syn match	freebasicFunctions		"\<option\ze\s*("

if s:lang == "qb"
  syn keyword	freebasicFunctions		__CVA_ARG __CVA_COPY __CVA_END __CVA_LIST __CVA_START
  syn keyword	freebasicFunctions		__VA_ARG __VA_FIRST __VA_NEXT
else
  syn keyword	freebasicFunctions		CVA_ARG CVA_COPY CVA_END CVA_LIST CVA_START
  syn keyword	freebasicFunctions		VA_ARG VA_FIRST VA_NEXT
  syn keyword	freebasicFunctions		ANY OVERLOAD
endif

syn keyword	freebasicFunctions		FUNCTION SUB
syn match	freebasicFunctions		"\<end\s\+function\>"
syn match	freebasicFunctions		"\<end\s\+sub\>"

if s:lang == "fb"
  syn keyword	freebasicFunctions		ABSTRACT OVERRIDE VIRTUAL __THISCALL
  syn keyword	freebasicFunctions		CONSTRUCTOR DESTRUCTOR OPERATOR PROPERTY
  syn match	freebasicFunctions		"\<end\s\+constructor\>"
  syn match	freebasicFunctions		"\<end\s\+destructor\>"
  syn match	freebasicFunctions		"\<end\s\+operator\>"
  syn match	freebasicFunctions		"\<end\s\+property\>"
else
  syn keyword	freebasicFunctions		CALL
endif

syn match	freebasicGraphics		"\<palette\s\+get\>"
syn keyword	freebasicGraphics		ADD ALPHA BLOAD BSAVE CIRCLE CLS COLOR DRAW GET
syn keyword	freebasicGraphics		LINE PAINT PALETTE PCOPY PMAP POINT
syn keyword	freebasicGraphics		PRESET PSET PUT SCREEN
syn keyword	freebasicGraphics		TRANS WINDOW
if s:lang == "qb"
  syn keyword	freebasicGraphics		__FLIP __IMAGECONVERTROW __IMAGECREATE __IMAGEDESTROY __IMAGEINFO __POINTCOORD
  syn keyword	freebasicGraphics		__RGB __RGBA __SCREENCOPY __SCREENCONTROL __SCREENEVENT __SCREENGLPROC __SCREENINFO
  syn keyword	freebasicGraphics		__SCREENLIST __SCREENLOCK __SCREENPTR __SCREENRES __SCREENSET __SCREENSYNC
  syn keyword	freebasicGraphics		__SCREENUNLOCK __WINDOWTITLE
else
  syn keyword	freebasicGraphics		CUSTOM
  syn keyword	freebasicGraphics		FLIP IMAGECONVERTROW IMAGECREATE IMAGEDESTROY IMAGEINFO POINTCOORD
  syn keyword	freebasicGraphics		RGB RGBA SCREENCOPY SCREENCONTROL SCREENEVENT SCREENGLPROC SCREENINFO
  syn keyword	freebasicGraphics		SCREENLIST SCREENLOCK SCREENPTR SCREENRES SCREENSET SCREENSYNC
  syn keyword	freebasicGraphics		SCREENUNLOCK WINDOWTITLE
endif

if s:lang != "qb"
  syn match	freebasicHardware		"\<open\s\+\%(com\|lpt\)\>"
endif
syn keyword	freebasicHardware		INP OUT WAIT LPOS LPRINT

syn keyword	freebasicMath			ABS ATN COS EXP FIX FRAC INT LOG MOD RANDOMIZE RND SGN SIN SQR TAN

if s:lang == "qb"
  syn keyword	freebasicMath			__ACOS __ASIN __ATAN2
else
  syn keyword	freebasicMath			ACOS ASIN ATAN2
endif

if s:lang == "qb"
  syn keyword	freebasicMemory			__ALLOCATE __CALLOCATE __DEALLOCATE __REALLOCATE
else
  syn keyword	freebasicMemory			ALLOCATE CALLOCATE DEALLOCATE REALLOCATE
  syn keyword	freebasicMemory			PEEK POKE CLEAR FB_MEMCOPY FB_MEMCOPYCLEAR FB_MEMMOVE SWAP SADD
  syn keyword	freebasicMemory			FIELD FRE
endif

syn keyword	freebasicMisc			LET TO
if s:lang == "qb"
  syn keyword freebasicMisc			__OFFSETOF
else
  syn keyword freebasicMisc			OFFSETOF
endif

syn keyword	freebasicModularizing		CHAIN COMMON
if s:lang == "fb"
  syn keyword	freebasicModularizing		EXTERN
  syn match	freebasicModularizing		"\<end\s\+extern\>"
  syn keyword	freebasicModularizing		PROTECTED
endif
if s:lang == "qb"
  syn keyword	freebasicModularizing		__EXPORT __IMPORT __DYLIBFREE __DYLIBLOAD __DYLIBSYMBOL
else
  syn keyword	freebasicModularizing		EXPORT IMPORT DYLIBFREE DYLIBLOAD DYLIBSYMBOL
  syn keyword	freebasicModularizing		PRIVATE PUBLIC
  syn keyword	freebasicModularizing		NAMESPACE
  syn match	freebasicModularizing		"\<end\s\+namespace\>"
endif

if s:lang != "qb"
  syn keyword	freebasicMultithreading		MUTEXCREATE MUTEXDESTROY MUTEXLOCK MUTEXUNLOCK THREADCREATE THREADWAIT
  syn keyword	freebasicMultithreading		CONDBROADCAST CONDCREATE CONDDESTROY CONDSIGNAL CONDWAIT
  syn keyword	freebasicMultithreading		THREADCALL THREADDETACH THREADSELF
endif

syn keyword	freebasicShell			CHDIR KILL NAME MKDIR RMDIR RUN SETENVIRON
if s:lang == "qb"
  syn keyword	freebasicShell			__CURDIR __DIR __EXEC __EXEPATH
  syn match	freebasicString			"\<\%(command\|environ\)\$"
else
  " fbio.bi
  syn keyword	freebasicShell			ISREDIRECTED
  syn keyword	freebasicShell			CURDIR DIR EXEC EXEPATH
  syn match	freebasicString			"\<\%(command\|environ\)\>\$\="
endif

syn keyword	freebasicEnviron		SHELL SYSTEM

syn keyword	freebasicLoops			FOR LOOP WHILE WEND DO STEP UNTIL NEXT
if s:lang == "qb"
  syn keyword	freebasicLoops			__CONTINUE
else
  syn keyword	freebasicLoops			CONTINUE
endif
"
"	File numbers
"
syn match	freebasicFilenumber		"#\d\+"
syn match	freebasicFilenumber		"#\a[[:alpha:].]*[%&!#]\="

syn match	freebasicMetacommand		"$\s*\%(dynamic\|static\)"
syn match	freebasicMetacommand		"$\s*include\s*\%(once\)\=\s*:\s*'[^']\+'"
syn match	freebasicMetacommand		'$\s*include\s*\%(once\)\=\s*:\s*"[^"]\+"'
syn match	freebasicMetacommand		'$\s*lang\s*:\s*"[^"]\+"'
"
"	Intrinsic defines
"
syn keyword	freebasicPredefined		__DATE__ __DATE_ISO__
syn keyword	freebasicPredefined		__FB_64BIT__ __FB_ARGC__ __FB_ARG_COUNT__ __FB_ARG_EXTRACT__ __FB_ARG_LEFTOF__
syn keyword	freebasicPredefined		__FB_ARG_RIGHTOF__ __FB_ARGV__ __FB_ARM__ __FB_ASM__ __FB_BACKEND__
syn keyword	freebasicPredefined		__FB_BIGENDIAN__ __FB_BUILD_DATE__ __FB_BUILD_DATE_ISO__ __FB_BUILD_SHA1__
syn keyword	freebasicPredefined		__FB_CYGWIN__ __FB_DARWIN__ __FB_DEBUG__ __FB_DOS__ __FB_ERR__ __FB_EVAL__
syn keyword	freebasicPredefined		__FB_FPMODE__ __FB_FPU__ __FB_FREEBSD__ __FB_GCC__ __FB_GUI__ __FB_IIF__ __FB_JOIN__
syn keyword	freebasicPredefined		__FB_LANG__ __FB_LINUX__ __FB_MAIN__ __FB_MIN_VERSION__ __FB_MT__ __FB_NETBSD__
syn keyword	freebasicPredefined		__FB_OPENBSD__ __FB_OPTIMIZE__ __FB_OPTION_BYVAL__ __FB_OPTION_DYNAMIC__
syn keyword	freebasicPredefined		__FB_OPTION_ESCAPE__ __FB_OPTION_EXPLICIT__ __FB_OPTION_GOSUB__
syn keyword	freebasicPredefined		__FB_OPTION_PRIVATE__ __FB_OUT_DLL__ __FB_OUT_EXE__ __FB_OUT_LIB__ __FB_OUT_OBJ__
syn keyword	freebasicPredefined		__FB_PCOS__ __FB_PPC__ __FB_QUERY_SYMBOL__ __FB_QUOTE__ __FB_SIGNATURE__ __FB_SSE__
syn keyword	freebasicPredefined		__FB_UNIQUEID__ __FB_UNIQUEID_POP__ __FB_UNIQUEID_PUSH__ __FB_UNIX__ __FB_UNQUOTE__
syn keyword	freebasicPredefined		__FB_VECTORIZE__ __FB_VER_MAJOR__ __FB_VER_MINOR__ __FB_VER_PATCH__ __FB_VERSION__
syn keyword	freebasicPredefined		__FB_WIN32__ __FB_X86__ __FB_XBOX__
syn keyword	freebasicPredefined		__FILE__ __FILE_NQ__ __FUNCTION__ __FUNCTION_NQ__
syn keyword	freebasicPredefined		__LINE__ __PATH__ __TIME__
"
"	Preprocessor directives
"
syn match	freebasicInclude		"#\s*\%(inclib\|include\%(\s\+once\)\=\|libpath\)\>"

syn match	freebasicPreProcessor		"#\s*assert\>"
syn match	freebasicPreProcessor		"#\s*cmdline\>"
syn match	freebasicPreProcessor		"#\s*\%(define\|undef\)\>"
syn match	freebasicPreProcessor		"#\s*\%(if\|ifdef\|ifndef\|else\|elseif\|endif\)\>"
syn match	freebasicPreProcessor		"#\s*\%(macro\|endmacro\)\>"
syn match	freebasicPreProcessor		"#\s*error\>"
syn match	freebasicPreProcessor		"#\s*lang\>"
syn match	freebasicPreProcessor		"#\s*line\>"
syn match	freebasicPreProcessor		"#\s*pragma\%(\s\+reserve\)\=\>"
syn match	freebasicPreProcessor		"#\s*\%(print\|dynamic\|static\)\>"
syn keyword	freebasicPreProcessor		DEFINED

syn keyword	freebasicString			LEN
syn keyword	freebasicString			ASC
" string.bi
syn keyword	freebasicString			FORMAT
syn keyword	freebasicString			VAL
syn keyword	freebasicString			CVD CVI CVL CVS
syn keyword	freebasicString			INSTR
syn keyword	freebasicString			LSET RSET

if s:lang == "qb"
  syn match	freebasicString			"\<string\$\ze\s*("
  syn match	freebasicString			"\<__wstring\ze\s*("
  syn match	freebasicString			"\<space\$"
  syn keyword	freebasicString			__WSPACE
  syn match	freebasicString			"\<chr\$"
  syn keyword	freebasicString			__WCHR
  syn keyword	freebasicString			__WBIN __WHEX __WOCT __WSTR
  syn match	freebasicString			"\<\%(bin\|hex\|oct\|str\)\$"
  syn keyword	freebasicString			__VALLNG __VALINT __VALUINT __VALULNG
  syn match	freebasicString			"\<\%(mkd\|mki\|mkl\|mks\)\$"
  syn keyword	freebasicString			__MKLONGINT __MKSHORT
  syn keyword	freebasicString			__CVLONGINT __CVSHORT
  syn match	freebasicString			"\<\%(left\|mid\|right\|lcase\|ucase\|ltrim\|rtrim\)\$"
  syn keyword	freebasicString			__TRIM
  syn keyword	freebasicString			__INSTRREV
else
  syn match	freebasicString			"\<string\$\=\ze\s*("
  syn match	freebasicString			"\<wstring\ze\s*("
  syn match	freebasicString			"\<space\>\$\="
  syn keyword	freebasicString			WSPACE
  syn match	freebasicString			"\<chr\>\$\="
  syn keyword	freebasicString			WCHR
  syn keyword	freebasicString			WBIN WHEX WOCT WSTR
  syn match	freebasicString			"\<\%(bin\|hex\|oct\|str\)\>\$\="
  syn keyword	freebasicString			VALLNG VALINT VALUINT VALULNG
  syn match	freebasicString			"\<\%(mkd\|mki\|mkl\|mks\)\>\$\="
  syn match	freebasicString			"\<\%(mklongint\|mkshort\)\>\$\="
  syn keyword	freebasicString			CVLONGINT CVSHORT
  syn match	freebasicString			"\<\%(left\|mid\|right\|lcase\|ucase\|ltrim\|rtrim\)\>\$\="
  syn match	freebasicString			"\<trim\>\$\="
  syn keyword	freebasicString			INSTRREV
endif

syn keyword	freebasicTypeCasting		CDBL CINT CLNG CSNG
if s:lang == "qb"
  syn keyword	freebasicTypeCasting		__CAST __CBOOL __CBYTE __CLNGINT __CPTR __CSHORT __CSIGN __CYBTE __CUINT __CULNG
  syn keyword	freebasicTypeCasting		__CULNGINT __CUNSG __CUSHORT
else
  syn keyword	freebasicTypeCasting		CAST CBOOL CBYTE CLNGINT CPTR CSHORT CSIGN CUBYTE CUINT CULNG CULNGINT CUNSG CUSHORT
endif

syn match	freebasicUserInput		"\<line\s\+input\>"
syn keyword	freebasicUserInput		INKEY INPUT
if s:lang == "qb"
  syn keyword	freebasicUserInput		__GETJOYSTICK __GETKEY __GETMOUSE __MULTIKEY __SETMOUSE STICK STRIG
else
  syn keyword	freebasicUserInput		GETJOYSTICK GETKEY GETMOUSE MULTIKEY SETMOUSE
endif
"
"	Operators
"
" TODO: make these context sensitive to remove the overlap of common operators
"     : alpha operators should probably always be highlighted
"     -- DJK 20/11/19
if s:lang == "qb"
  syn match	freebasicArithmeticOperator	"\<\%(MOD\|__SHL\|__SHR\)\>"
else
  syn match	freebasicArithmeticOperator	"\<\%(MOD\|SHL\|SHR\)\>"
endif
syn match	freebasicBitwiseOperator	"\<\%(AND\|EQV\|IMP\|NOT\|OR\|XOR\)\>" " freebaseLogical?
if s:lang == "qb"
  syn match	freebasicAssignmentOperator	"\<\%(MOD\|AND\|EQV\|IMP\|OR\|XOR\|__SHL\|__SHR\)=\@=" " exclude trailing '='
else
  syn match	freebasicAssignmentOperator	"\<\%(MOD\|AND\|EQV\|IMP\|OR\|XOR\|SHL\|SHR\)=\@="
endif
syn match	freebasicShortcircuitOperator	"\<\%(ANDALSO\|ORELSE\)\>"
if s:lang == "fb"
  syn match	freebasicMemoryOperator		'\<\%(new\|delete\)\>'
endif
syn keyword	freebasicPointerOperator	STRPTR VARPTR
if s:lang == "qb"
  syn keyword	freebasicPointerOperator	__PROCPTR
else
  syn keyword	freebasicPointerOperator	PROCPTR
endif
syn match	freebasicTypeOperator		'\<is\>'
syn match	freebasicTypeOperator		'\.' nextgroup=freebasicIdentifier skipwhite
if s:lang == "fb"
  syn match	freebasicTypeOperator		'->' nextgroup=freebasicIdentifier skipwhite
endif

if exists("freebasic_operators")
  syn match	freebasicAssignmentOperator	"=>\=\|[-+&/\\*^]="
  if s:lang == "qb"
    syn match	freebasicAssignmentOperator	"\<\%(MOD\|AND\|EQV\|IMP\|OR\|XOR\|__SHL\|__SHR\)=" " include trailing '='
  else
    syn match	freebasicAssignmentOperator	"\<\%(MOD\|AND\|EQV\|IMP\|OR\|XOR\|SHL\|SHR\)="
  endif
  syn match	freebasicArithmeticOperator	"[-+&/\\*^]"
  " syn match	freebasicIndexingOperator	"[[\]()]" " FIXME
  syn match	freebasicRelationalOperator	"=\|<>\|<=\|<\|>=\|>"
  syn match	freebasicPreprocessorOperator	'\%(^\s*\)\@<!\%(##\|#\)\|[$!]"\@='
  syn match	freebasicPointerOperator	'[@*]'
  syn match	freebasicTypeOperator		'\.' nextgroup=freebasicIdentifier skipwhite
  if s:lang == "fb"
    syn match	freebasicTypeOperator		'->' nextgroup=freebasicIdentifier skipwhite
  endif
endif

syn cluster	freebasicOperator		contains=freebasic.*Operator
"
"	Catch errors caused by wrong parenthesis
"
" syn region	freebasicParen		transparent start='(' end=')' contains=ALLBUT,@freebasicParenGroup
" syn match	freebasicParenError	")"
" syn match	freebasicInParen	contained "[{}]"
" syn cluster	freebasicParenGroup	contains=freebasicParenError,freebasicSpecial,freebasicTodo,freebasicUserCont,freebasicUserLabel,freebasicBitField
"
"	Integer number
"
syn match	freebasicHexError	"&h\w*\>"
syn match	freebasicOctalError	"&o\w*\>"
syn match	freebasicBinaryError	"&b\w*\>"
syn match	freebasicHex		"&h\x\+\%([%L&U]\|UL\|LL\|ULL\)\=\>"
syn match	freebasicOctal		"&o\o\+\%([%L&U]\|UL\|LL\|ULL\)\=\>"
syn match	freebasicBinary		"&b[10]\+\%([%L&U]\|UL\|LL\|ULL\)\=\>"
syn match	freebasicInteger	"\<\d\+\%([%L&U]\|UL\|LL\|ULL\)\=\>"
"
"	Floating point
"	See: https://www.freebasic.net/forum/viewtopic.php?t=20323
"
"	Floating point number, with dot, optional exponent, optional suffix
"
syn match	freebasicFloat		"\<\d\+\.\d*\%([de][-+]\=\d*\)\=[f!#]\="
"
"	Floating point number, starting with a dot, optional exponent, optional suffix
"
syn match	freebasicFloat		"\.\d\+\%([de][-+]\=\d*\)\=[f!#]\="
"
"	Floating point number, without dot, with optional exponent, optional suffix
"
syn match	freebasicFloat		"\<\d\+\%([de][-+]\=\d*\)[f!#]\="
"
"	Floating point number, without dot, without exponent, with suffix
"
syn match	freebasicFloat		"\<\d\+[f!#]"
"
"	Create the clusters
"
syn cluster	freebasicNumber		contains=freebasicHex,freebasicOctal,freebasicBinary,freebasicInteger,freebasicFloat
syn cluster	freebasicNumberError	contains=freebasicHexError,freebasicOctalError,freebasicBinaryError
"
"	Booleans
"
if s:lang != "qb"
  syn keyword	freebasicBoolean	TRUE FALSE
endif
"
"
"	String and escape sequences
"
syn match	freebasicSpecial	contained "\\."
syn match	freebasicSpecial	contained "\\\d\{1,3}"
syn match	freebasicSpecial	contained "\\&h\x\{1,2}"
syn match	freebasicSpecial	contained "\\&o\o\{1,3}"
syn match	freebasicSpecial	contained "\\&b[01]\{1,8}"
syn match	freebasicSpecial	contained "\\u\x\{1,4}"
syn region	freebasicString		start='"'     end='"' " TODO: Toggle contains on Option Escape in fblite and qb? -- DJK 20/11/19
syn region	freebasicString		start='!\zs"' end='"' contains=freebasicSpecial
syn region	freebasicString		start='$\zs"' end='"'
"
"	Line labels
"
if s:lang =~# '\<\%(qb\|fblite\)\>'
  syn match	freebasicLineLabel	"^\s*\zs\h\%(\w\|\.\)*\ze\s*:"
else
  syn match	freebasicLineLabel	"^\s*\zs\h\w*\ze\s*:"
endif
syn match	freebasicLineNumber	"^\s*\zs\d\+"
"
"	Line continuations
"
" syn match	freebasicLineContinuation	"\<_\>"	nextgroup=freebasicComment,freebasicPostLineContinuation skipwhite
syn keyword	freebasicLineContinuation	_	nextgroup=freebasicComment,freebasicPostLineContinuation skipwhite
syn match	freebasicPostLineContinuation	".*"	contained
"
"
" Type suffixes
if exists("freebasic_type_suffixes") && s:lang =~# '\<\%(qb\|fblite\)\>'
  syn match freebasicTypeSuffix "\h\%(\w\|.\)*\zs[$%&!#]"
endif
"
"	Comments
"
syn keyword	freebasicTodo			TODO FIXME XXX NOTE      contained
syn region	freebasicComment		start="\<rem\>" end="$"  contains=freebasicTodo,@Spell,freebasicMetacommand
syn region	freebasicComment		start="'"	end="$"  contains=freebasicTodo,@Spell,freebasicMetacommand
syn region	freebasicDoubleComment		start="''"	end="$"  contains=freebasicTodo,@Spell

if !exists("freebasic_no_comment_fold")
  syn region	freebasicMultilineComment	start="/'"	end="'/" contains=freebasicTodo,@Spell,freeBasicMultilineComment fold keepend extend
  syn region	freebasicMultilineComment2	start="^\s*'.*\n\%(\s*'\)\@=" end="^\s*'.*\n\%(\s*'\)\@!" contains=freebasicComment,freebasicDoubleComment keepend fold
else
  syn region	freebasicMultilineComment	start="/'"	end="'/" contains=freebasicTodo,@Spell,freeBasicMultilineComment
endif

syn case match

syn sync linebreaks=1

"
"	The default methods for highlighting.  Can be overridden later
"
hi def link freebasicArrays		StorageClass
hi def link freebasicAsm		Special
hi def link freebasicBitManipulation	Operator
hi def link freebasicBoolean		Boolean
if s:lang == "fb"
  hi def link freebasicCompilerSwitches	freebasicUnsupportedError
else
  hi def link freebasicCompilerSwitches	PreCondit
endif
hi def link freebasicConsole		Special
hi def link freebasicData		Special
hi def link freebasicDataTypes		Type
hi def link freebasicDateTime		Type
hi def link freebasicDebug		Special
hi def link freebasicErrorHandling	Special
hi def link freebasicFilenumber		Special
hi def link freebasicFiles		Special
hi def link freebasicFunctions		Function
hi def link freebasicGraphics		Function
hi def link freebasicHardware		Special
hi def link freebasicLoops		Repeat
hi def link freebasicMath		Function
if s:lang == "fb"
  hi def link freebasicMetacommand	freebasicUnsupportedError
else
  hi def link freebasicMetacommand	SpecialComment
endif
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
hi def link freebasicDoubleComment	Comment
hi def link freebasicMultilineComment	Comment
hi def link freebasicConditional	Conditional
hi def link freebasicError		Error
hi def link freebasicIdentifier		Identifier
hi def link freebasicInclude		Include
hi def link freebasicGenericFunction	Function
hi def link freebasicLineContinuation	Special
hi def link freebasicLineLabel		LineNr
if s:lang == "fb"
  hi def link freebasicLineNumber	freebasicUnsupportedError
else
  hi def link freebasicLineNumber	LineNr
endif
hi def link freebasicMathOperator	Operator

hi def link freebasicHex		Number
hi def link freebasicOctal		Number
hi def link freebasicBinary		Number
hi def link freebasicInteger		Number
hi def link freebasicFloat		Float

hi def link freebasicHexError		Error
hi def link freebasicOctalError		Error
hi def link freebasicBinaryError	Error

hi def link freebasicAssignmentOperator		Operator
hi def link freebasicArithmeticOperator		Operator
hi def link freebasicIndexingOperator		Operator
hi def link freebasicRelationalOperator		Operator
hi def link freebasicBitwiseOperator		Operator
hi def link freebasicShortcircuitOperator	Operator
hi def link freebasicPreprocessorOperator	Operator
hi def link freebasicPointerOperator		Operator
if exists("freebasic_operators")
  hi def link freebasicTypeOperator		Operator
endif
hi def link freebasicMemoryOperator		Operator

hi def link freebasicSpaceError			Error

hi def link freebasicSpecial		Special
hi def link freebasicTodo		Todo

hi def link freebasicUnsupported	freebasicUnsupportedError
hi def link freebasicUnsupportedError	Error

unlet s:lang

let b:current_syntax = "freebasic"

" vim: ts=8 tw=132 fdm=marker
