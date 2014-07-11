" Vim syntax file
" Language:	Informix 4GL
" Maintainer:	Rafal M. Sulejman <rms@poczta.onet.pl>
" Update:	26 Sep 2002
" Changes:
" - Dynamic 4GL/FourJs/4GL 7.30 pseudo comment directives (Julian Bridle)
" - Conditionally allow case insensitive keywords (Julian Bridle)
"

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

if exists("fgl_ignore_case")
  syntax case ignore
else
  syntax case match
endif
syn keyword fglKeyword ABORT ABS ABSOLUTE ACCEPT ACCESS ACOS ADD AFTER ALL
syn keyword fglKeyword ALLOCATE ALTER AND ANSI ANY APPEND ARG_VAL ARRAY ARR_COUNT
syn keyword fglKeyword ARR_CURR AS ASC ASCENDING ASCII ASIN AT ATAN ATAN2 ATTACH
syn keyword fglKeyword ATTRIBUTE ATTRIBUTES AUDIT AUTHORIZATION AUTO AUTONEXT AVERAGE AVG
syn keyword fglKeyword BEFORE BEGIN BETWEEN BLACK BLINK BLUE BOLD BORDER BOTH BOTTOM
syn keyword fglKeyword BREAK BUFFERED BY BYTE
syn keyword fglKeyword CALL CASCADE CASE CHAR CHARACTER CHARACTER_LENGTH CHAR_LENGTH
syn keyword fglKeyword CHECK CLASS_ORIGIN CLEAR CLIPPED CLOSE CLUSTER COLOR
syn keyword fglKeyword COLUMN COLUMNS COMMAND COMMENT COMMENTS COMMIT COMMITTED
syn keyword fglKeyword COMPOSITES COMPRESS CONCURRENT CONNECT CONNECTION
syn keyword fglKeyword CONNECTION_ALIAS CONSTRAINED CONSTRAINT CONSTRAINTS CONSTRUCT
syn keyword fglKeyword CONTINUE CONTROL COS COUNT CREATE CURRENT CURSOR CYAN
syn keyword fglKeyword DATA DATABASE DATASKIP DATE DATETIME DAY DBA DBINFO DBSERVERNAME
syn keyword fglKeyword DEALLOCATE DEBUG DEC DECIMAL DECLARE DEFAULT DEFAULTS DEFER
syn keyword fglKeyword DEFERRED DEFINE DELETE DELIMITER DELIMITERS DESC DESCENDING
syn keyword fglKeyword DESCRIBE DESCRIPTOR DETACH DIAGNOSTICS DIM DIRTY DISABLED
syn keyword fglKeyword DISCONNECT DISPLAY DISTINCT DISTRIBUTIONS DO DORMANT DOUBLE
syn keyword fglKeyword DOWN DOWNSHIFT DROP
syn keyword fglKeyword EACH ELIF ELSE ENABLED END ENTRY ERROR ERRORLOG ERR_GET
syn keyword fglKeyword ERR_PRINT ERR_QUIT ESC ESCAPE EVERY EXCEPTION EXCLUSIVE
syn keyword fglKeyword EXEC EXECUTE EXISTS EXIT EXP EXPLAIN EXPRESSION EXTEND EXTENT
syn keyword fglKeyword EXTERN EXTERNAL
syn keyword fglKeyword F1 F10 F11 F12 F13 F14 F15 F16 F17 F18 F19 F2 F20 F21 F22 F23
syn keyword fglKeyword F24 F25 F26 F27 F28 F29 F3 F30 F31 F32 F33 F34 F35 F36 F37 F38
syn keyword fglKeyword F39 F4 F40 F41 F42 F43 F44 F45 F46 F47 F48 F49 F5 F50 F51 F52
syn keyword fglKeyword F53 F54 F55 F56 F57 F58 F59 F6 F60 F61 F62 F63 F64 F7 F8 F9
syn keyword fglKeyword FALSE FETCH FGL_GETENV FGL_KEYVAL FGL_LASTKEY FIELD FIELD_TOUCHED
syn keyword fglKeyword FILE FILLFACTOR FILTERING FINISH FIRST FLOAT FLUSH FOR
syn keyword fglKeyword FOREACH FOREIGN FORM FORMAT FORMONLY FORTRAN FOUND FRACTION
syn keyword fglKeyword FRAGMENT FREE FROM FUNCTION GET_FLDBUF GLOBAL GLOBALS GO GOTO
syn keyword fglKeyword GRANT GREEN GROUP HAVING HEADER HELP HEX HIDE HIGH HOLD HOUR
syn keyword fglKeyword IDATA IF ILENGTH IMMEDIATE IN INCLUDE INDEX INDEXES INDICATOR
syn keyword fglKeyword INFIELD INIT INITIALIZE INPUT INSERT INSTRUCTIONS INT INTEGER
syn keyword fglKeyword INTERRUPT INTERVAL INTO INT_FLAG INVISIBLE IS ISAM ISOLATION
syn keyword fglKeyword ITYPE
syn keyword fglKeyword KEY LABEL
syn keyword fglKeyword LANGUAGE LAST LEADING LEFT LENGTH LET LIKE LINE
syn keyword fglKeyword LINENO LINES LOAD LOCATE LOCK LOG LOG10 LOGN LONG LOW
syn keyword fglKeyword MAGENTA MAIN MARGIN MATCHES MAX MDY MEDIUM MEMORY MENU MESSAGE
syn keyword fglKeyword MESSAGE_LENGTH MESSAGE_TEXT MIN MINUTE MOD MODE MODIFY MODULE
syn keyword fglKeyword MONEY MONTH MORE
syn keyword fglKeyword NAME NCHAR NEED NEW NEXT NEXTPAGE NO NOCR NOENTRY NONE NORMAL
syn keyword fglKeyword NOT NOTFOUND NULL NULLABLE NUMBER NUMERIC NUM_ARGS NVARCHAR
syn keyword fglKeyword OCTET_LENGTH OF OFF OLD ON ONLY OPEN OPTIMIZATION OPTION OPTIONS
syn keyword fglKeyword OR ORDER OTHERWISE OUTER OUTPUT
syn keyword fglKeyword PAGE PAGENO PAUSE PDQPRIORITY PERCENT PICTURE PIPE POW PRECISION
syn keyword fglKeyword PREPARE PREVIOUS PREVPAGE PRIMARY PRINT PRINTER PRIOR PRIVATE
syn keyword fglKeyword PRIVILEGES PROCEDURE PROGRAM PROMPT PUBLIC PUT
syn keyword fglKeyword QUIT QUIT_FLAG
syn keyword fglKeyword RAISE RANGE READ READONLY REAL RECORD RECOVER RED REFERENCES
syn keyword fglKeyword REFERENCING REGISTER RELATIVE REMAINDER REMOVE RENAME REOPTIMIZATION
syn keyword fglKeyword REPEATABLE REPORT REQUIRED RESOLUTION RESOURCE RESTRICT
syn keyword fglKeyword RESUME RETURN RETURNED_SQLSTATE RETURNING REVERSE REVOKE RIGHT
syn keyword fglKeyword ROBIN ROLE ROLLBACK ROLLFORWARD ROOT ROUND ROW ROWID ROWIDS
syn keyword fglKeyword ROWS ROW_COUNT RUN
syn keyword fglKeyword SCALE SCHEMA SCREEN SCROLL SCR_LINE SECOND SECTION SELECT
syn keyword fglKeyword SERIAL SERIALIZABLE SERVER_NAME SESSION SET SET_COUNT SHARE
syn keyword fglKeyword SHORT SHOW SITENAME SIZE SIZEOF SKIP SLEEP SMALLFLOAT SMALLINT
syn keyword fglKeyword SOME SPACE SPACES SQL SQLAWARN SQLCA SQLCODE SQLERRD SQLERRM
syn keyword fglKeyword SQLERROR SQLERRP SQLSTATE SQLWARNING SQRT STABILITY START
syn keyword fglKeyword STARTLOG STATIC STATISTICS STATUS STDEV STEP STOP STRING STRUCT
syn keyword fglKeyword SUBCLASS_ORIGIN SUM SWITCH SYNONYM SYSTEM
syn keyword fglKeyword SysBlobs SysChecks SysColAuth SysColDepend SysColumns
syn keyword fglKeyword SysConstraints SysDefaults SysDepend SysDistrib SysFragAuth
syn keyword fglKeyword SysFragments SysIndexes SysObjState SysOpClstr SysProcAuth
syn keyword fglKeyword SysProcBody SysProcPlan SysProcedures SysReferences SysRoleAuth
syn keyword fglKeyword SysSynTable SysSynonyms SysTabAuth SysTables SysTrigBody
syn keyword fglKeyword SysTriggers SysUsers SysViews SysViolations
syn keyword fglKeyword TAB TABLE TABLES TAN TEMP TEXT THEN THROUGH THRU TIME TO
syn keyword fglKeyword TODAY TOP TOTAL TRACE TRAILER TRAILING TRANSACTION TRIGGER
syn keyword fglKeyword TRIGGERS TRIM TRUE TRUNC TYPE TYPEDEF
syn keyword fglKeyword UNCOMMITTED UNCONSTRAINED UNDERLINE UNION UNIQUE UNITS UNLOAD
syn keyword fglKeyword UNLOCK UNSIGNED UP UPDATE UPSHIFT USER USING
syn keyword fglKeyword VALIDATE VALUE VALUES VARCHAR VARIABLES VARIANCE VARYING
syn keyword fglKeyword VERIFY VIEW VIOLATIONS
syn keyword fglKeyword WAIT WAITING WARNING WEEKDAY WHEN WHENEVER WHERE WHILE WHITE
syn keyword fglKeyword WINDOW WITH WITHOUT WORDWRAP WORK WRAP WRITE
syn keyword fglKeyword YEAR YELLOW
syn keyword fglKeyword ZEROFILL

" Strings and characters:
syn region fglString		start=+"+  skip=+\\\\\|\\"+  end=+"+
syn region fglString		start=+'+  skip=+\\\\\|\\"+  end=+'+

" Numbers:
syn match fglNumber		"-\=\<[0-9]*\.\=[0-9_]\>"

" Comments:
syn region fglComment    start="{"  end="}"
syn match fglComment	"--.*"
syn match fglComment	"#.*"

" Not a comment even though it looks like one (Dynamic 4GL/FourJs directive)
syn match fglSpecial	"--#"
syn match fglSpecial	"--@"

syn sync ccomment fglComment

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_fgl_syntax_inits")
  if version < 508
    let did_fgl_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink fglComment	Comment
  "HiLink fglKeyword	fglSpecial
  HiLink fglKeyword	fglStatement
  HiLink fglNumber	Number
  HiLink fglOperator	fglStatement
  HiLink fglSpecial	Special
  HiLink fglStatement	Statement
  HiLink fglString	String
  HiLink fglType	Type

  delcommand HiLink
endif

let b:current_syntax = "fgl"

" vim: ts=8
