" Vim syntax file
" Modified from  http://plnet.org/files/vim/
" using keywords from http://www.kednos.com/pli/docs/reference_manual/6291pro_contents.html
"    2012-11-13 Alan Thompson

" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

syn case ignore

" Todo.
syn keyword pl1Todo TODO FIXME XXX DEBUG NOTE

" pl1CommentGroup allows adding matches for special things in comments
" 20010723az: Added this so that these could be matched in comments...  
syn cluster pl1CommentGroup contains=pl1Todo

syn match   pl1Garbage        "[^ \t()]"
syn match   pl1Identifier     "[a-z][a-z0-9$_#]*"
syn match   pl1HostIdentifier ":[a-z][a-z0-9$_#]*"

" 20010723az: When wanted, highlight the trailing whitespace -- this is
" based on c_space_errors 
if exists("c_space_errors")
    if !exists("c_no_trail_space_error")
        syn match pl1SpaceError "\s\+$"
    endif
    if !exists("c_no_tab_space_error")
        syn match pl1SpaceError " \+\t"me=e-1
    endif
endif

" Symbols.  
syn match   pl1Symbol         "\(;\|,\|\.\)"
syn match   pl1PreProcSym     "%"

" Operators.
syn match   pl1Operator       "\(&\|:\|!\|+\|-\|\*\|/\|=\|<\|>\|@\|\*\*\|!=\|\~=\)"
syn match   pl1Operator       "\(\^\|\^=\|<=\|>=\|:=\|=>\|\.\.\|||\|<<\|>>\|\"\)"

" Attributes
syn keyword pl1Attribute BACKWARDS BUFFERED BUF CONNECTED CONN CONSTANT EVENT
syn keyword pl1Attribute EXCLUSIVE EXCL FORMAT GENERIC IRREDUCIBLE IRRED LOCAL
syn keyword pl1Attribute REDUCIBLE RED TASK TRANSIENT UNBUFFERED UNBUF ALIGNED ANY
syn keyword pl1Attribute AREA AUTOMATIC AUTO BASED BUILTIN CONDITION COND CONTROLLED
syn keyword pl1Attribute CTL DEFINED DEF DIRECT ENVIRONMENT ENV EXTERNAL EXT FILE
syn keyword pl1Attribute GLOBALDEF GLOBALREF INITIAL INIT INPUT INTERNAL INT KEYED
syn keyword pl1Attribute LABEL LIKE LIST MEMBER NONVARYING NONVAR OPTIONAL OPTIONS
syn keyword pl1Attribute OUTPUT PARAMETER PARM PICTURE PIC POSITION POS PRECISION
syn keyword pl1Attribute PREC PRINT READONLY RECORD REFER RETURNS SEQUENTIAL SEQL
syn keyword pl1Attribute STATIC STREAM STRUCTURE TRUNCATE UNALIGNED UNAL UNION UPDATE
syn keyword pl1Attribute VARIABLE VARYING VAR COMPLEX CPLX REAL BINARY BIN BIT
syn keyword pl1Attribute CHARACTER CHAR DECIMAL DEC DESCRIPTOR DESC DIMENSION DIM
syn keyword pl1Attribute FIXED FLOAT OFFSET POINTER PTR REFERENCE VALUE VAL 

" Functions
syn keyword pl1Function AFTER ALL ANY BEFORE COMPLETION CPLN CONJG COUNT
syn keyword pl1Function CURRENTSTORAGE CSTG DATAFIELD DECAT DOT ERF ERFC IMAG
syn keyword pl1Function ONCOUNT ONFIELD ONLOC POLY PRIORITY REPEAT SAMEKEY STATUS
syn keyword pl1Function STORAGE STG ABS ACOS ACTUALCOUNT ADD ADDR ADDREL ALLOCATION
syn keyword pl1Function ALLOCN ASIN ATAN ATAND ATANH BOOL BYTE BYTESIZE CEIL COLLATE
syn keyword pl1Function COPY COS COSD COSH DATE DATETIME DECODE DISPLAY DIVIDE EMPTY
syn keyword pl1Function ENCODE ERROR EVERY EXP EXTEND FLOOR FLUSH FREE HBOUND HIGH
syn keyword pl1Function INDEX INFORM INT LBOUND LENGTH LINE LINENO LOG LOG10 LOG2
syn keyword pl1Function LOW LTRIM MAX MAXLENGTH MIN MOD MULTIPLY NEXT_VOLUME NULL
syn keyword pl1Function ONARGSLIST ONCHAR ONCODE ONFILE ONKEY ONSOURCE PAGENO POSINT
syn keyword pl1Function PRESENT PROD RANK RELEASE RESIGNAL REVERSE REWIND ROUND
syn keyword pl1Function RTRIM SEARCH SIGN SIN SIND SINH SIZE SOME SPACEBLOCK SQRT
syn keyword pl1Function STRING SUBSTR SUBTRACT SUM TAN TAND TANH TIME TRANSLATE TRIM
syn keyword pl1Function TRUNC UNSPEC VALID VARIANT VERIFY WARN 

" Other keywords
syn keyword pl1Other ATTENTION ATTN C CONVERSION CONV DATA NAME NOCONVERSION
syn keyword pl1Other NOCONV NOFIXEDOVERFLOW NOFOFL NOOVERFLOW NOSIZE
syn keyword pl1Other NOSTRINGRANGE NOSTRG NOSTRINGSIZE NOSTRZ NOSUBSCRIPTRANGE
syn keyword pl1Other NOSUBRG NOZERODIVIDE NOZDIV OVERFLOW OFL PENDING RECORD
syn keyword pl1Other REENTRANT SIZE STRINGRANGE STRG STRINGSIZE STRZ
syn keyword pl1Other SUBSCRIPTRANGE SUBRG TRANSMIT A ANYCONDITION APPEND B B1 B2
syn keyword pl1Other B3 B4 BACKUP_DATE BATCH BLOCK_BOUNDARY_FORMAT BLOCK_IO
syn keyword pl1Other BLOCK_SIZE BUCKET_SIZE BY CANCEL_CONTROL_O
syn keyword pl1Other CARRIAGE_RETURN_FORMAT COLUMN COL CONTIGUOUS
syn keyword pl1Other CONTIGUOUS_BEST_TRY CONVERSION CONV CREATION_DATE
syn keyword pl1Other CURRENT_POSITION DEFAULT_FILE_NAME DEFERRED_WRITE E EDIT
syn keyword pl1Other ENDFILE ENDPAGE EXPIRATION_DATE EXTENSION_SIZE F FAST_DELETE
syn keyword pl1Other FILE_ID FILE_ID_TO FILE_SIZE FINISH FIXEDOVERFLOW FOFL
syn keyword pl1Other FIXED_CONTROL_FROM FIXED_CONTROL_SIZE FIXED_CONTROL_SIZE_TO
syn keyword pl1Other FIXED_CONTROL_TO FIXED_LENGTH_RECORDS FROM GROUP_PROTECTION
syn keyword pl1Other IDENT IGNORE_LINE_MARKS IN INDEXED INDEX_NUMBER INITIAL_FILL
syn keyword pl1Other INTO KEY KEYFROM KEYTO LINESIZE LOCK_ON_READ LOCK_ON_WRITE
syn keyword pl1Other MAIN MANUAL_UNLOCKING MATCH_GREATER MATCH_GREATER_EQUAL
syn keyword pl1Other MATCH_NEXT MATCH_NEXT_EQUAL MAXIMUM_RECORD_NUMBER
syn keyword pl1Other MAXIMUM_RECORD_SIZE MULTIBLOCK_COUNT MULTIBUFFER_COUNT
syn keyword pl1Other NOLOCK NONEXISTENT_RECORD NONRECURSIVE NO_ECHO NO_FILTER
syn keyword pl1Other NO_SHARE OVERFLOW OFL OWNER_GROUP OWNER_ID OWNER_MEMBER
syn keyword pl1Other OWNER_PROTECTION P PAGE PAGESIZE PRINTER_FORMAT PROMPT
syn keyword pl1Other PURGE_TYPE_AHEAD R READ_AHEAD READ_CHECK READ_REGARDLESS
syn keyword pl1Other RECORD_ID RECORD_ID_ACCESS RECORD_ID_TO RECURSIVE REPEAT
syn keyword pl1Other RETRIEVAL_POINTERS REVISION_DATE REWIND_ON_CLOSE
syn keyword pl1Other REWIND_ON_OPEN SCALARVARYING SET SHARED_READ SHARED_WRITE
syn keyword pl1Other SKIP SPOOL STORAGE STRINGRANGE STRG SUBSCRIPTRANGE SUBRG
syn keyword pl1Other SUPERSEDE SYSIN SYSPRINT SYSTEM_PROTECTION TAB TEMPORARY
syn keyword pl1Other TIMEOUT_PERIOD TITLE TO UNDEFINEDFILE UNDF UNDERFLOW UFL
syn keyword pl1Other UNTIL USER_OPEN VAXCONDITION WAIT_FOR_RECORD WHILE
syn keyword pl1Other WORLD_PROTECTION WRITE_BEHIND WRITE_CHECK X ZERODIVIDE ZDIV 

" PreProcessor keywords
syn keyword pl1PreProc ACTIVATE DEACTIVATE DECLARE DCL DICTIONARY DO END ERROR
syn keyword pl1PreProc FATAL GOTO IF INCLUDE INFORM LIST NOLIST PAGE PROCEDURE PROC
syn keyword pl1PreProc REPLACE RETURN SBTTL TITLE WARN THEN ELSE 

" Statements
syn keyword pl1Statement CALL SUB ENTRY BY NAME CASE CHECK COPY DEFAULT DFT DELAY
syn keyword pl1Statement DESCRIPTORS DISPLAY EXIT FETCH HALT IGNORE LIST LOCATE
syn keyword pl1Statement NOCHECK NOLOCK NONE ORDER RANGE RELEASE REORDER REPLY SNAP
syn keyword pl1Statement SYSTEM TAB UNLOCK WAIT ALLOCATE ALLOC BEGIN CALL CLOSE
syn keyword pl1Statement DECLARE DCL DELETE DO ELSE END FORMAT GET GOTO GO TO IF
syn keyword pl1Statement LEAVE NORESCAN ON OPEN OTHERWISE OTHER PROCEDURE PROC PUT
syn keyword pl1Statement READ RESCAN RETURN REVERT REWRITE SELECT SIGNAL SNAP
syn keyword pl1Statement STATEMENT STOP SYSTEM THEN WHEN WRITE 

" PL1's own keywords
" syn match   pl1Keyword "\<END\>"
" syn match   pl1Keyword "\.COUNT\>"hs=s+1
" syn match   pl1Keyword "\.EXISTS\>"hs=s+1
" syn match   pl1Keyword "\.FIRST\>"hs=s+1
" syn match   pl1Keyword "\.LAST\>"hs=s+1
" syn match   pl1Keyword "\.DELETE\>"hs=s+1
" syn match   pl1Keyword "\.PREV\>"hs=s+1
" syn match   pl1Keyword "\.NEXT\>"hs=s+1

if exists("pl1_highlight_triggers")
    syn keyword pl1Trigger  INSERTING UPDATING DELETING
endif

" Conditionals.
syn keyword pl1Conditional ELSIF ELSE IF
syn match   pl1Conditional "\<END\s\+IF\>"

" Loops.
syn keyword pl1Repeat FOR LOOP WHILE FORALL
syn match   pl1Repeat "\<END\s\+LOOP\>"

" Various types of comments.
" 20010723az: Added the ability to treat strings within comments just like
" C does.
if exists("c_comment_strings")
    syntax match pl1CommentSkip contained "^\s*\*\($\|\s\+\)"
    syntax region pl1CommentString contained start=+L\="+ skip=+\\\\\|\\"+ end=+"+ end=+\*/+me=s-1 contains=pl1CommentSkip
    syntax region pl1Comment2String contained start=+L\="+ skip=+\\\\\|\\"+ end=+"+ end="$"
    syntax region pl1CommentL start="--" skip="\\$" end="$" keepend contains=@pl1CommentGroup,pl1Comment2String,pl1CharLiteral,pl1BooleanLiteral,pl1NumbersCom,pl1SpaceError
    syntax region pl1Comment start="/\*" end="\*/" contains=@pl1CommentGroup,pl1Comment2String,pl1CharLiteral,pl1BooleanLiteral,pl1NumbersCom,pl1SpaceError
else
    syntax region pl1CommentL start="--" skip="\\$" end="$" keepend contains=@pl1CommentGroup,pl1SpaceError
    syntax region pl1Comment start="/\*" end="\*/" contains=@pl1CommentGroup,pl1SpaceError
endif

" 20010723az: These are the old comment commands ... commented out.
" syn match   pl1Comment    "--.*$" contains=pl1Todo
" syn region  pl1Comment    start="/\*" end="\*/" contains=pl1Todo
syn sync ccomment pl1Comment
syn sync ccomment pl1CommentL

" To catch unterminated string literals.
syn match   pl1StringError    "'.*$"

" Various types of literals.
" 20010723az: Added stuff for comment matching.
syn match pl1Numbers transparent "\<[+-]\=\d\|[+-]\=\.\d" contains=pl1IntLiteral,pl1FloatLiteral
syn match pl1NumbersCom contained transparent "\<[+-]\=\d\|[+-]\=\.\d" contains=pl1IntLiteral,pl1FloatLiteral
syn match pl1IntLiteral contained "[+-]\=\d\+"
syn match pl1FloatLiteral contained "[+-]\=\d\+\.\d*"
syn match pl1FloatLiteral contained "[+-]\=\d*\.\d*"
"syn match pl1FloatLiteral "[+-]\=\([0-9]*\.[0-9]\+\|[0-9]\+\.[0-9]\+\)\(e[+-]\=[0-9]\+\)\="
syn match   pl1CharLiteral    "'[^']'"
syn match   pl1StringLiteral  "'\([^']\|''\)*'"
syn keyword pl1BooleanLiteral TRUE FALSE NULL

" The built-in types.
syn keyword pl1Storage ANYDATA ANYTYPE BFILE BINARY_INTEGER BLOB BOOLEAN
syn keyword pl1Storage BYTE CHAR CHARACTER CLOB CURSOR DATE DAY DEC DECIMAL
syn keyword pl1Storage DOUBLE DSINTERVAL_UNCONSTRAINED FLOAT HOUR
syn keyword pl1Storage INT INTEGER INTERVAL LOB LONG MINUTE
syn keyword pl1Storage MLSLABEL MONTH NATURAL NATURALN NCHAR NCHAR_CS NCLOB
syn keyword pl1Storage NUMBER NUMERIC NVARCHAR PLS_INT PLS_INTEGER
syn keyword pl1Storage POSITIVE POSITIVEN PRECISION RAW REAL RECORD
syn keyword pl1Storage SECOND SIGNTYPE SMALLINT STRING SYS_REFCURSOR TABLE TIME
syn keyword pl1Storage TIMESTAMP TIMESTAMP_UNCONSTRAINED
syn keyword pl1Storage TIMESTAMP_TZ_UNCONSTRAINED
syn keyword pl1Storage TIMESTAMP_LTZ_UNCONSTRAINED UROWID VARCHAR
syn keyword pl1Storage VARCHAR2 YEAR YMINTERVAL_UNCONSTRAINED ZONE

" A type-attribute is really a type.
" 20020916bp: Removed leading part of pattern to avoid highlighting the
"             object
syn match   pl1TypeAttribute  "%\(TYPE\|ROWTYPE\)\>"

" All other attributes.
syn match   pl1Attribute "%\(BULK_EXCEPTIONS\|BULK_ROWCOUNT\|ISOPEN\|FOUND\|NOTFOUND\|ROWCOUNT\)\>"

" Catch errors caused by wrong parentheses and brackets
" 20010723az: significantly more powerful than the values -- commented out
" below the replaced values. This adds the C functionality to PL/SQL.
syn cluster pl1ParenGroup contains=pl1ParenError,@pl1CommentGroup,pl1CommentSkip,pl1IntLiteral,pl1FloatLiteral,pl1NumbersCom
if exists("c_no_bracket_error")
    syn region pl1Paren transparent start='(' end=')' contains=ALLBUT,@pl1ParenGroup
    syn match pl1ParenError ")"
    syn match pl1ErrInParen contained "[{}]"
else
    syn region pl1Paren transparent start='(' end=')' contains=ALLBUT,@pl1ParenGroup,pl1ErrInBracket
    syn match pl1ParenError "[\])]"
    syn match pl1ErrInParen contained "[{}]"
    syn region pl1Bracket transparent start='\[' end=']' contains=ALLBUT,@pl1ParenGroup,pl1ErrInParen
    syn match pl1ErrInBracket contained "[);{}]"
endif
" syn region pl1Paren       transparent start='(' end=')' contains=ALLBUT,pl1ParenError
" syn match pl1ParenError   ")"

" Syntax Synchronizing
syn sync minlines=10 maxlines=100

" Define the default highlighting.
" Only when and item doesn't have highlighting yet.

hi def link pl1Attribute       Macro
hi def link pl1BlockError      Error
hi def link pl1BooleanLiteral  Boolean
hi def link pl1CharLiteral     Character
hi def link pl1Comment         Comment
hi def link pl1CommentL        Comment
hi def link pl1Conditional     Conditional
hi def link pl1Error           Error
hi def link pl1ErrInBracket    Error
hi def link pl1ErrInBlock      Error
hi def link pl1ErrInParen      Error
hi def link pl1Exception       Function
hi def link pl1FloatLiteral    Float
hi def link pl1Function        Function
hi def link pl1Garbage         Error
hi def link pl1HostIdentifier  Label
hi def link pl1Identifier      Normal
hi def link pl1IntLiteral      Number
hi def link pl1Operator        Operator
hi def link pl1Paren           Normal
hi def link pl1ParenError      Error
hi def link pl1SpaceError      Error
hi def link pl1Pseudo          PreProc
hi def link pl1PreProc         PreProc
hi def link pl1PreProcSym      PreProc
hi def link pl1Keyword         Keyword
hi def link pl1Other           Keyword
hi def link pl1Repeat          Repeat
hi def link pl1Statement       Keyword
hi def link pl1Storage         StorageClass
hi def link pl1StringError     Error
hi def link pl1StringLiteral   String
hi def link pl1CommentString   String
hi def link pl1Comment2String  String
hi def link pl1Symbol          Normal
hi def link pl1Trigger         Function
hi def link pl1TypeAttribute   StorageClass
hi def link pl1Todo            Todo


let b:current_syntax = "pl1"
