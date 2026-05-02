" Vim syntax file
" Language:		Algol 68
" Version:		0.4
" Maintainer:		Janis Papanagnou
" Previous Maintainer:	NevilleD.ALGOL_68@sgr-a.net
" Last Change:		2026 May 02

if exists("b:current_syntax")
  finish
endif

syn sync minlines=250 maxlines=500

" Algol68 Final Report, unrevised
syn keyword algol68PreProc	PRIORITY
syn keyword algol68Operator	BTB CTB CONJ QUOTE CT CTAB EITHER SIGN


" Algol68 Revised Report
syn keyword algol68Boolean	TRUE FALSE
syn keyword algol68Conditional	IF THEN ELSE ELIF FI
syn keyword algol68Conditional	CASE IN OUT OUSE ESAC
syn keyword algol68Constant	NIL SKIP EMPTY
syn keyword algol68Statement	MODE OP PRIO PROC
syn keyword algol68Label	GOTO 
syn match   algol68Label	"\<GO TO\>"
syn keyword algol68Operator	ABS REPR ROUND ENTIER ARG BIN LENG SHORTEN ODD
syn keyword algol68Operator	SHL SHR ROL ROR UP DOWN LEVEL LWB UPB I RE IM
syn keyword algol68Operator	OVER MOD ELEM SET CLEAR
syn keyword algol68Operator	LT LE GE GT
syn keyword algol68Operator	EQ NE
syn keyword algol68Operator	AND OR XOR NOT
" Genie short-circuit pseudo operators
syn keyword algol68Operator	THEF ANDF ANDTH ELSF ORF OREL
syn keyword algol68Operator	ANDTHEN ORELSE
syn keyword algol68Operator	MINUSAB PLUSAB TIMESAB DIVAB OVERAB MODAB PLUSTO
syn keyword algol68Operator	IS ISNT OF AT
syn keyword algol68Operator	SORT ELEMS
syn keyword algol68Repeat	FOR FROM BY UPTO DOWNTO TO WHILE DO UNTIL OD
syn keyword algol68Statement	PAR BEGIN END EXIT
syn keyword algol68Struct	STRUCT
syn keyword algol68PreProc	VECTOR
syn keyword algol68Type		FLEX HEAP LOC LONG REF SHORT
syn keyword algol68Type		VOID BOOL INT REAL COMPL CHAR STRING COMPLEX
syn keyword algol68Type		BITS BYTES FILE CHANNEL PIPE SEMA SOUND
syn keyword algol68Type		FORMAT STRUCT UNION 
" Genie extensions in addition to ROUND and ENTIER
syn keyword algol68Operator	FLOOR CEIL NINT TRUNC FRAC FIX

    " 20011222az: Added new items.
syn keyword algol68Todo contained	TODO FIXME XXX DEBUG NOTE


" String
syn region  algol68String	matchgroup=algol68String start=+"+ end=+"+ contains=algol68StringEscape
syn match   algol68StringEscape	contained '""'
syn match   algol68StringEscape	contained "\\$"


syn match   algol68Identifier		"\<[a-z][a-z0-9_]*\>"


if exists("algol68_symbolic_operators")
  syn match   algol68SymbolOperator	"\\"
  syn match   algol68SymbolOperator	":=\|="
  syn match   algol68SymbolOperator	"[~^]"
  syn match   algol68SymbolOperator	"[~^]="
  syn match   algol68SymbolOperator	"[<>]"
  syn match   algol68SymbolOperator	"[<>]="
  syn match   algol68SymbolOperator	"\%([-+*%/]\|%\*\)"
  syn match   algol68SymbolOperator	"\%([-+*%/]\|%\*\):="
  syn match   algol68SymbolOperator	"+=:"
  syn match   algol68SymbolOperator	"*\*\|&"
  syn match   algol68SymbolOperator	":/\==:"
endif

syn match  algol68Number	"\<\d\+\%(\s\+\d\+\)*\>"

syn match  algol68Float		"\c\.\d\+\%(\s\+\d\+\)*\%(\s*[e\\⏨]\s*[-+]\?\s*\d\+\%(\s\+\d\+\)*\)\?\>"
syn match  algol68Float		"\c\<\d\+\%(\s\+\d\+\)*\%(\s*[e\\⏨]\s*[-+]\?\s*\d\+\%(\s\+\d\+\)*\)\>"
syn match  algol68Float		"\c\<\d\+\%(\s\+\d\+\)*\s*\.\s*\d\+\%(\s\+\d\+\)*\%(\s*[e\\⏨]\s*[-+]\?\s*\d\+\%(\s\+\d\+\)*\)\?\>"

syn match  algol68HexNumber	"\c\<2r\s*[01]\+\%(\s\+[01]\+\)*\>"
syn match  algol68HexNumber	"\c\<4r\s*[0-3]\+\%(\s\+[0-3]\+\)*\>"
syn match  algol68HexNumber	"\c\<8r\s*[0-7]\+\%(\s\+[0-7]\+\)*\>"
syn match  algol68HexNumber	"\c\<16r\s*[0-9a-f]\+\%(\s\+[0-9a-f]\+\)*\>"


syn region algol68Special	start="\$"  end="\$" contains=algol68String
syn region algol68Comment	start="¢"  end="¢" contains=algol68Todo,algol68SpaceError
syn region algol68Comment	start="£"  end="£" contains=algol68Todo,algol68SpaceError
syn region algol68Comment	start="#"  end="#" contains=algol68Todo,algol68SpaceError
syn region algol68Comment	start="\<CO\>"  end="\<CO\>" contains=algol68Todo,algol68SpaceError
syn region algol68Comment	start="\<COMMENT\>"  end="\<COMMENT\>" contains=algol68Todo,algol68SpaceError
syn region algol68PreProc	start="\<PR\>"  end="\<PR\>" contains=algol68Todo,algol68SpaceError
syn region algol68PreProc	start="\<PRAGMAT\>"  end="\<PRAGMAT\>" contains=algol68Todo,algol68SpaceError
" algol68r
syn region algol68Comment	start="{"  end="}" contains=algol68Todo,algol68SpaceError
syn region algol68Comment	start="{{{"  end="}}}" contains=algol68Todo,algol68SpaceError

" ALGOL 68r
syn keyword algol68PreProc DECS CONTEXT configinfo A68CONFIG KEEP FINISH USE SYSPROCS IOSTATE FORALL
" ALGOL 68c
syn keyword algol68PreProc USING ENVIRON FOREACH ASSERT

if !exists("algol68_no_preludes")


"  THE STANDARD ENVIRONMENT

"      Enquiries
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(blank\|formfeed\|newline\|null\|tab\|eof\)\s*char\%(acter\)\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(max\s*abs\|exp\|error\)\s*char\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(long\s*\)\?long\s*\)\?max\s*\%(bits\|int\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(long\s*\)\?long\s*\)\?\%(max\|min\|small\)\s*real\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(\%(long\s*\)\?long\s*\)\?\%(bits\|bytes\|exp\|int\|real\)\s*width\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(bits\|bytes\|compl\|int\|real\)\s*\%(lengths\|shorths\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(blank\|flip\|flop\)\>\%(\s*[a-z0-9]\)\@!"

"      Transput Files and Channels
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<stand\s*\%(in\|out\|back\|error\)\%(\s*channel\)\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<stand\s*draw\s*channel\>\%(\s*[a-z0-9]\)\@!"

"      Transput Event Routines
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<on\s*\%(\%(line\|page\|\%(logical\s*\|physical\s*\)\?file\|format\)\s*\)end\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<on\s*\%(\%(format\|value\|open\|transput\)\s*\)error\>\%(\s*[a-z0-9]\)\@!"

"      Connections to Files
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(open\|establish\|append\|create\|associate\|close\|lock\|erase\|scratch\)\>\%(\s*[a-z0-9]\)\@!"

"      Positioning on Files
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<new\s*line\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<new\s*page\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<back\s*space\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(reset\|rewind\|rewrite\|set\|seek\|space\)\>\%(\s*[a-z0-9]\)\@!"

"      I/O on Files (Standard)
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(get\|put\|print\|read\|write\)\%(f\|\s*bin\)\?\>\%(\s*[a-z0-9]\)\@!"

"      I/O on Files (Algol68C)
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(print\|read\)\s*\%(\%(long\s*\)\?long\s*\)\?\%(int\|real\|complex\|bits\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(print\|read\)\s*\%(bool\|char\|string\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<read\s*line\>\%(\s*[a-z0-9]\)\@!"

"      Enquiries on Files
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(get\|put\|bin\|set\|reset\|rewind\|reidf\|draw\)\s*possible\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<end\s*of\s*\%(file\|line\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(make\s*\)\?term\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(compressible\|eof\|eoln\)\>\%(\s*[a-z0-9]\)\@!"

"      Keyboard Control
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cooked\|raw\)\>\%(\s*[a-z0-9]\)\@!"

"      Math Constants
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(long\s*\)\?long\s*\)\?\%(min\s*real\|\%(minus\s*\)\?infinity\|\%(min\s*\)\?inf\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(\%(long\s*\)\?long\s*\)\|[qd]\)\?pi\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<mp\s*radix\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<nan\>\%(\s*[a-z0-9]\)\@!"

"      Math Basic Functions
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\%([a-z0-9]\s\+\)\@8<!\<\%(\%(\%(long\s*\)\?long\s*\)\|[qd]\)\?\%(sqrt\|cbrt\|curt\|exp\|ln\|log\)\>\%(\s*[a-z0-9]\)\@!\%(\s\{1,7}[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<ln\s*abs\>\%(\s*[a-z0-9]\)\@!"

"      Math Trigonometric Functions
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(\%(long\s*\)\?long\s*\)\|[qd]\)\?\%(arc\s*\|a\)\?\%(sin\|cos\|tan\|cot\|sec\|csc\|cas\)\%(h\|\%(\s*dg\)\)\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(\%(long\s*\)\?long\s*\)\|[qd]\)\?\%(arc\s*\|a\)\?tan2\%(\s*dg\)\?\>\%(\s*[a-z0-9]\)\@!"
  " long-long-sinpi/cospi/tanpi/cotpi
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(\%(long\s*\)\?long\s*\)\|[qd]\)\?\%(sin\|cos\|tan\|cot\)\s*pi\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<ln\s*\%(sinh\|cosh\)\>\%(\s*[a-z0-9]\)\@!"
  " a special case in Genie?
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<atan\s*int\>\%(\s*[a-z0-9]\)\@!"

"      Random Number Generator
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(long\s*\)\?long\s*\)\?\%(next\s*\)\?random\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<first\s*random\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<rnd\>\%(\s*[a-z0-9]\)\@!"

"      Garbage Collection and Memory
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<collect\s*seconds\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<garbage\%(\s*\%(collections\|freed\|refused\|seconds\)\)\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<gc\s*heap\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<on\s*gc\s*event\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<preemptive\s*\%(gc\|sweep\%(\s*heap\)\?\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<sweep\s*heap\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<sweeps\%(\s*refused\)\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(system\s*\)\?\%(heap\|stack\)\s*pointer\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(actual\|system\)\s*stack\s*size\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(blocks\|collections\)\>\%(\s*[a-z0-9]\)\@!"

"      I/O on Strings
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(puts\|gets\|string\)f\?\>\%(\s*[a-z0-9]\)\@!"
"      Character Type Tests
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<is\s*\%(alnum\|alpha\|cntrl\|digit\|graph\|lower\|print\|punct\|space\|upper\|xdigit\)\>\%(\s*[a-z0-9]\)\@!"
"      Operations on Characters
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<to\s*\%(upper\|lower\)\>\%(\s*[a-z0-9]\)\@!"
"      Search in Strings
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(char\|last\s*char\|string\)\s*in\s*string\>\%(\s*[a-z0-9]\)\@!"

"      Time and Date
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cpu\|wall\|utc\|local\)\s*time\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(wall\s*\)\?clock\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(wall\s*\)\?seconds\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<sleep\>\%(\s*[a-z0-9]\)\@!"

"      Type Operations
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(long\s*\)\?\%(bits\|bytes\)\s*pack\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(long\s*long\s*\)\?bits\s*pack\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\%([a-z0-9]\s\+\)\@8<!\<\%(bits\|whole\|fixed\|float\|real\)\>\%(\s*[a-z0-9]\)\@!\%(\s*[a-z0-9]\)\@!"

"      Runtime
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(program\s*\)\?idf\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(backtrace\|break\|debug\|monitor\|abend\|evaluate\|system\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(i32\|i64\|r64\|r128\)mach\>\%(\s*[a-z0-9]\)\@!"


"  UNIX EXTENSIONS

"      Environment Functions
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(a68g\s*\)\?\%(argc\|argv\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<get\s*env\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<reset\s*errno\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<str\s*error\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(get\|set\)\s*pwd\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(rows\|columns\|abend\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<errno\>\%(\s*[a-z0-9]\)\@!"

"      Processes
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<execve\%(\s*child\%(\s*pipe\)\?\|\s*output\)\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<exec\%(\s*sub\%(\s*pipeline\|\s*output\)\?\)\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<fork\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<wait\s*pid\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<create\s*pipe\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<peek\s*char\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<sig\s*segv\>\%(\s*[a-z0-9]\)\@!"

"      File types and attributes
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<file\s*is\s*\%(block\s*device\|char\s*device\|directory\|regular\|fifo\|link\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<file\s*mode\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<get\s*directory\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<real\s*path\>\%(\s*[a-z0-9]\)\@!"

"      Fetching web page contents and sending requests
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<https\?\s*\%(content\|timeout\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<tcp\s*request\>\%(\s*[a-z0-9]\)\@!"

"      Regular expressions in string manipulation
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<grep\s*in\s*\%(sub\)\?string\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<sub\s*in\s*string\>\%(\s*[a-z0-9]\)\@!"

"      Curses support
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<curses\s*\%(start\|end\|clear\|refresh\|get\s*char\|put\s*char\|move\|lines\|columns\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<curses\s*\%(green\|cyan\|red\|yellow\|magenta\|blue\|white\)\%(\s*inverse\)\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<curses\s*del\s*char\>\%(\s*[a-z0-9]\)\@!"


"  POSTGRESQL CLIENT ROUTINES

"      Connecting to a server
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<pq\s*\%(connect\s*db\|finish\|reset\|parameter\s*status\)\>\%(\s*[a-z0-9]\)\@!"

"      Sending queries and retrieving results
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<pq\s*\%(exec\|ntuples\|nfields\|fname\|fnumber\|fformat\|get\s*is\s*null\|get\s*value\|cmd\s*status\|cmd\s*tuples\)\>\%(\s*[a-z0-9]\)\@!"

"      Connection status information
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<pq\s*\%(\%(result\s*\)\?error\s*message\|db\|user\|pass\|host\|port\|tty\|options\|\%(protocol\|server\)\s*version\|socket\|backend\s*pid\)\>\%(\s*[a-z0-9]\)\@!"


"  SOUND

  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(new\|get\|set\)\s*sound\>\%(\s*[a-z0-9]\)\@!"
  syn keyword algol68Operator RESOLUTION CHANNELS RATE SAMPLES


"  DRAWING USING THE GNU PLOTTING UTILITIES

"      Setting up a graphics device
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<draw\s*\%(device\|erase\|show\|move\|aspect\|fill\s*style\|line\s*style\|line\s*width\|clear\|flush\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<make\s*device\>\%(\s*[a-z0-9]\)\@!"

"      Specifying colours
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<draw\s*\%(\%(background\s*\)\?colou\?r\%(\s*name\)\?\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<draw\s*get\s*colou\?r\s*name\>\%(\s*[a-z0-9]\)\@!"

"      Drawing objects
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<draw\s*\%(point\|line\|rect\|circle\|ball\|star\)\>\%(\s*[a-z0-9]\)\@!"

"      Drawing text
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<draw\s*\%(text\%(\s*angle\)\?\|font\s*\%(name\|size\)\)\>\%(\s*[a-z0-9]\)\@!"


"  EXTRA NUMERICAL PROCEDURES

"      COMPLEX Functions
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(\%(long\s*\)\?long\s*\)\|[qd]\)\?c\%(omplex\s*\)\?\%(sqrt\|exp\|ln\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(long\s*\)\?long\s*\)\?complex\s*\%(arc\s*\)\?\%(sin\|cos\|tan\)h\?\>\%(\s*[a-z0-9]\)\@!"
  " cas casin casinh dcas dcasin dcasinh qcas qcasin qcasinh longcas longlongcas
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(\%(long\s*\)\?long\s*\)\|[dq]\?\)ca\?\%(sin\|cos\|tan\)h\?\>\%(\s*[a-z0-9]\)\@!"
  " a special case in Genie?
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<long\s*complex\s*atanh\>\%(\s*[a-z0-9]\)\@!"

"      REAL Airy Functions
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<airy\s*[ab]i\%(\s*deriv\)\?\%(\s*scaled\)\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<airy\s*[ab]i\%(\s*derivative\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<airy\s*zero\s*[ab]i\%(\s*deriv\)\?\>\%(\s*[a-z0-9]\)\@!"

"      REAL Bessel Functions
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<bessel\s*\%(jn\|yn\|in\|exp\s*in\|kn\|exp\s*kn\|jl\|yl\|exp\s*il\|exp\s*kl\|jnu\|ynu\|inu\|exp\s*inu\|knu\|exp\s*knu\)\>\%(\s*[a-z0-9]\)\@!"

  " only a few could be sensibly merged; we keep them apart
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<bessel\s*\%(il[012]\?\s*scaled\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<bessel\s*\%(in[01]\%(\s*scaled\)\?\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<bessel\s*\%(in\s*u\?\s*scaled\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<bessel\s*\%(j\%(\l[012]\|n[01]\)\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<bessel\s*\%(kl[012]\?\s*scaled\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<bessel\s*\%(kn[01]\%(\s*scaled\)\?\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<bessel\s*\%(kn\s*[u_]\?\s*scaled\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<bessel\s*ln\s*knu\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<bessel\s*\%(y\%(\l[012]\|n[01]\)\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<bessel\s*zero\s*j\%([01]\|nu\)\>\%(\s*[a-z0-9]\)\@!"

"      REAL Elliptic Integrals
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<elliptic\s*integral\s*\%(k\|e\|rf\<rd\|rj\|rc\)\>\%(\s*[a-z0-9]\)\@!"

"      REAL Error and Gamma Functions
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(ln\s*\)\?\%(fact\|choose\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<prime\s*factors\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(\%(long\s*\)\?long\s*\)\|[qd]\)\?\%(inv\%(erse\)\?\s*\)\?erfc\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<mpfr\s*\%(\%(\%(long\s*\)\?long\s*\)\|q\)\?\%(inv\s*\)\?erfc\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(\%(\%(mpfr\s*\)\?long\s*\)\?long\s*\)\|\%(d\|\%(mpfr\s*\)\?q\)\)\?\%(beta\|gamma\)\%(\s*inc\s*g\?f\?\)\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<beta\s*inc\s*gsl\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(\%(\%(\%(mpfr\s*\)\?long\s*\)\?long\s*\)\|\%(d\|\%(mpfr\s*\)\?q\)\)\?ln\s*\%(beta\|gamma\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<mpfr\s*mp\>\%(\s*[a-z0-9]\)\@!"
  " is the following a special case in Genie?
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<mpfr\s*\%(long\s*\|d\)gamma\s*inc\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "gamma\s*\%(\%(inc\s*\%(gsl\|[pq]\)\)\|inv\|star\)\>\%(\s*\%([a-z_]\|\l\d\+\)\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<lj[ef]\s*126\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<ln1p\>\%(\s*[a-z0-9]\)\@!"



"      Scaling Factors

  " strangely missing some common factors (hecto, deca, deci, centi),
  " also myria, and the more extreme factors (quetta, ronna, ronto, quecto)
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<num\s*\%(yotta\|zetta\|exa\|peta\|tera\|giga\|mega\|kilo\|milli\|micro\|nano\|pico\|femto\|atto\|zepto\|yocto\)\>\%(\s*[a-z0-9]\)\@!"


"      Physical Constants

"          Fundamental Constants
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(boltzmann\|faraday\|gauss\|hectare\|\%(kilometers\|miles\)\s*per\s*hour\|micron\|molar\s*gas\|planck\s*constant\%(\s*bar\)\?\|speed\s*of\s*light\|standard\s*gas\s*volume\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<mksa\s*vacuum\s*\%(permeability\|permittivity\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<num\s*avogadro\>\%(\s*[a-z0-9]\)\@!"

"          Astronomy and Astrophysics
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(astronomical\s*unit\|grav\s*accel\|gravitational\s*constant\|light\s*year\|parsec\|solar\s*mass\)\>\%(\s*[a-z0-9]\)\@!"

"          Atomic and Nuclear Physics
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(angstrom\|barn\|bohr\s*magneton\|bohr\s*radius\|electron\s*\%(charge\|magnetic\s*moment\|volt\)\|mass\s*\%(electron\|muon\|neutron\|proton\)\|nuclear\s*magneton\|proton\s*magnetic\s*moment\|rydberg\|unified\s*atomic\s*mass\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<num\s*fine\s*structure\>\%(\s*[a-z0-9]\)\@!"

"          Time
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(day\|hour\|minute\|week\)\>\%(\s*[a-z0-9]\)\@!"

"          Imperial units
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(foot\|inch\|mil\|mile\|yard\|\%(tex\)\?point\)\>\%(\s*[a-z0-9]\)\@!"

"          Nautical units
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(fathom\|knot\|nautical\s*mile\)\>\%(\s*[a-z0-9]\)\@!"

"          Volume
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(acre\|\%(canadian\|uk\|us\)\s*gallon\|liter\|pint\|quart\|cup\|fluid\s*ounce\|\%(table\|tea\)\s*spoon\)\>\%(\s*[a-z0-9]\)\@!"

"          Mass and weight
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(carat\|\%(gram\|\%(kilo\s*\)\?pound\)\s*force\|\%(metric\s*\|uk\s*\)\?ton\|\%(ounce\|pound\)\s*mass\|poundal\|troy\s*ounce\)\>\%(\s*[a-z0-9]\)\@!"

"          Thermal energy and power
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(btu\|calorie\|horsepower\|therm\)\>\%(\s*[a-z0-9]\)\@!"

"          Pressure
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(bar\|inch\s*of\s*\%(mercury\|water\)\|meter\s*of\s*mercury\|psi\|std\s*atmosphere\|torr\)\>\%(\s*[a-z0-9]\)\@!"

"          Viscosity
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(poise\|stokes\)\>\%(\s*[a-z0-9]\)\@!"

"          Light and illumination
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(foot\s*candle\|foot\s*lambert\|lambert\|lumen\|lux\|phot\|stilb\)\>\%(\s*[a-z0-9]\)\@!"

"          Radioactivity
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(curie\|rad\|roentgen\)\>\%(\s*[a-z0-9]\)\@!"

"          Force and energy
  syn match algol68Predefined "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(cgs\|mksa\)\s*\%(dyne\|erg\|joule\|newton\)\>\%(\s*[a-z0-9]\)\@!"


" Functions from GSL

  syn keyword algol68Operator	CV RV T INV PINV MEAN DET TRACE NORM DYAD BEFORE ABOVE
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<angle\s*restrict\s*\%(pos\|symm\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<conical\s*p\s*\%([01]\|cylreg\|m\?half\|sph\s*reg\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<cholesky\s*\%(decomp\|solve\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<debye\s*[1-6]\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<ellint\s*\%([defp]\|[ekp]\s*comp\|r[cdfj]\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(expint\s*\%(3\|e[12in]\)\|expm1\|exprel[2n]\?\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<fermi\s*dirac\s*\%([012]\|3\?half\|inc0\|int\|m1\|mhalf\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<fft\s*\%(complex\s*\)\?\%(forward\|backward\|inverse\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(gegenpoly\|laguerre\)\s*[123n]\s*real\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<lambert\s*\%(w0\|wm1\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<legendre\s*\%(h3d\%([01]\)\?\|p[123l]\|q[01l]\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<pseudo\s*inv\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<psi\s*\%(1\%(\s*int\|\s*piy\)\?\|int\|n\)\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<synchrotron\s*[12]\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<taylor\s*coeff\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<transport\s*[2-5]\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<zeta\%(\s*m1\)\?\%(\s*int\)\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(chi\|ci\|clausen\|dawson\|digamma\|dilog\|\%(ln\s*\)\?doublefact\|eta\|eta\s*int\|hermite\s*func\|hypot\|hzeta\|laplace\|shi\|si\|sinc\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<ln1\s*\%(plusx\%(mx\)\?\)\?\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(compl\s*\)\?\%(matrix\|vector\)\s*echo\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<print\s*\%(matrix\|vector\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(complex\s*\)\?lu\s*\%(decomp\|det\|inv\|solve\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<left\s*columns\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(ols\|tls\|pcacv\|pcasvd\|pcr\|pls[12]\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<\%(ln\s*poch\|poch\s*\%(rel\)\?\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<qr\s*\%(decomp\|\%(ls\s*\)\?solve\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<svd\s*\%(decomp\|solve\)\>\%(\s*[a-z0-9]\)\@!"


" Functions from R Mathlib

  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<r\s*[dpqr]n\?\s*binom\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<r\s*\%(di\|tri\|tetra\|penta\|psi\)\s*gamma\>\%(\s*[a-z0-9]\)\@!"
  " note: Genie documents 'r rn chisq' but it's missing in the code?
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<r\s*[dpqr]n\?\s*chisq\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<r\s*[dpqr]\%(\s*n\)\?\s*f\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<r\s*[dpq]\%(\s*n\)\?\s*t\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<r\s*[dpqr]\s*\%(l\s*\)\?norm\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<r\s*[dpqr]\s*\%(beta\|cauchy\|exp\|geom\|hyper\|logis\|pois\|sign\s*rank\|t\|unif\|weibull\|wilcox\)\>\%(\s*[a-z0-9]\)\@!"
  syn match algol68Function "\%(\%([a-z_]\|\l\d\+\)\s\+\)\@8<!\<r\s*[pq]\s*tu\s*key\>\%(\s*[a-z0-9]\)\@!"


endif

" Define the default highlighting.
hi def link algol68Boolean		Boolean
hi def link algol68Comment		Comment
hi def link algol68Conditional		Conditional
hi def link algol68Constant		Constant
hi def link algol68Float		Float
hi def link algol68Function		Function
hi def link algol68Label		Label
hi def link algol68MatrixDelimiter	Identifier
hi def link algol68HexNumber		Number
hi def link algol68Number		Number
hi def link algol68Operator		Operator
hi def link algol68Predefined		Identifier
hi def link algol68PreProc		PreProc
hi def link algol68Repeat		Repeat
hi def link algol68SpaceError		Error
hi def link algol68Statement		Statement
hi def link algol68String		String
hi def link algol68StringEscape		Special
hi def link algol68Struct		algol68Statement
hi def link algol68SymbolOperator	algol68Operator
hi def link algol68Todo			Todo
hi def link algol68Type			Type
hi def link algol68ShowTab		Error

let b:current_syntax = "algol68"

" vim: ts=8 sw=2
