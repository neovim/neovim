" Vim syntax file
" Language:    SQL, SAP HANA In Memory Database
" Maintainer:  David Fishburn <dfishburn dot vim at gmail dot com>
" Last Change: 2012 Oct 23
" Version:     SP4 b (Q2 2012)
" Homepage:    http://www.vim.org/scripts/script.php?script_id=4275

" Description: Updated to SAP HANA SP4
"
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
    syntax clear
elseif exists("b:current_syntax")
    finish
endif

syn case ignore

" The SQL reserved words, defined as keywords.
" These were pulled from the following SQL reference:
"     http://help.sap.com/hana/hana_sql_en.pdf
" An easy approach is to copy all text from the PDF
" into a Vim buffer.  The keywords are in UPPER case,
" so you can run the following commands to be left with
" mainly the UPPER case words:
"   1.  Delete all words that do not begin with a Capital
"       %s/\(\<[^A-Z]\w*\>\)//g
"   2.  Remove all words where the 2nd letter is not a Capital
"       %s/\(\<[A-Z][^A-Z]\w*\>\)//g
"   3.  Remove all non-word (or space) characters
"       %s/[^0-9A-Za-z_ ]*//g
"   4.  Remove some known words
"       %s/\<\(SAP\|HANA\|OK\|AG\|IBM\|DB2\|AIX\|POWER\d\+\|UNIX\)\>//g
"   5.  Remove blank lines and trailing spaces
"       %s/\s\+$//g
"       %s/^\s\+//g
"       %s/^$\n//g
"   6.  Convert spaces to newlines remove single character
"       %s/[ ]\+/\r/g
"       %g/^\w$/d
"   7.  Sort and remove duplicates
"       :sort
"       :Uniq
"   8.  Use the WhatsMissing plugin against the sqlhana.vim file.
"   9.  Generated a file of all UPPER cased words which should not
"       be in the syntax file.  These items should be removed
"       from the list in step 7.  You can use WhatsNotMissing
"       between step 7 and this new file to weed out the words
"       we know are not syntax related.
"  10.  Use the WhatsMissingRemoveMatches to remove the words
"       from step 9.

syn keyword sqlSpecial  false null true

" Supported Functions for Date/Time types
syn keyword sqlFunction	 ADD_DAYS ADD_MONTHS ADD_SECONDS ADD_YEARS COALESCE
syn keyword sqlFunction	 CURRENT_DATE CURRENT_TIME CURRENT_TIMESTAMP CURRENT_UTCDATE
syn keyword sqlFunction	 CURRENT_UTCTIME CURRENT_UTCTIMESTAMP
syn keyword sqlFunction	 DAYNAME DAYOFMONTH DAYOFYEAR DAYS_BETWEEN EXTRACT
syn keyword sqlFunction	 GREATEST HOUR IFNULL ISOWEEK LAST_DAY LEAST LOCALTOUTC
syn keyword sqlFunction	 MINUTE MONTH MONTHNAME NEXT_DAY NOW QUARTER SECOND
syn keyword sqlFunction	 SECONDS_BETWEEN UTCTOLOCAL WEEK WEEKDAY YEAR

syn keyword sqlFunction	 TO_CHAR TO_DATE TO_DATS TO_NCHAR TO_TIME TO_TIMESTAMP UTCTOLOCAL

" Aggregate
syn keyword sqlFunction	 COUNT MIN MAX SUM AVG STDDEV VAR

" Datatype conversion
syn keyword sqlFunction	 CAST TO_ALPHANUM TO_BIGINT TO_BINARY TO_BLOB TO_CHAR TO_CLOB
syn keyword sqlFunction	 TO_DATE TO_DATS TO_DECIMAL TO_DOUBLE TO_INT TO_INTEGER TO_NCHAR
syn keyword sqlFunction	 TO_NCLOB TO_NVARCHAR TO_REAL TO_SECONDDATE TO_SMALLDECIMAL
syn keyword sqlFunction	 TO_SMALLINT TO_TIME TO_TIMESTAMP TO_TINYINT TO_VARCHAR TO_VARBINARY

" Number functions
syn keyword sqlFunction	 ABS ACOS ASIN ATAN ATAN2 BINTOHEX BITAND CEIL COS COSH COT
syn keyword sqlFunction	 EXP FLOOR GREATEST HEXTOBIN LEAST LN LOG MOD POWER ROUND
syn keyword sqlFunction	 SIGN SIN SINH SQRT TAN TANH UMINUS

" String functions
syn keyword sqlFunction	 ASCII CHAR CONCAT LCASE LENGTH LOCATE LOWER LPAD LTRIM
syn keyword sqlFunction	 NCHAR REPLACE RPAD RTRIM SUBSTR_AFTER SUBSTR_BEFORE
syn keyword sqlFunction	 SUBSTRING TRIM UCASE UNICODE UPPER

" Miscellaneous functions
syn keyword sqlFunction	 COALESCE CURRENT_CONNECTION CURRENT_SCHEMA CURRENT_USER
syn keyword sqlFunction	 GROUPING_ID IFNULL MAP NULLIF SESSION_CONTEXT SESSION_USER SYSUUIDSQL
syn keyword sqlFunction	 GET_NUM_SERVERS


" sp_ procedures
" syn keyword sqlFunction  sp_addalias


" Reserved keywords
syn keyword sqlkeyword   ALL AS AT BEFORE
syn keyword sqlkeyword   BEGIN BOTH BY
syn keyword sqlkeyword   CONDITION
syn keyword sqlkeyword   CURRVAL CURSOR DECLARE
syn keyword sqlkeyword   DISTINCT DO ELSE ELSEIF ELSIF
syn keyword sqlkeyword   END EXCEPTION EXEC
syn keyword sqlkeyword   FOR FROM GROUP
syn keyword sqlkeyword   HAVING IN
syn keyword sqlkeyword   INOUT INTO IS
syn keyword sqlkeyword   LEADING
syn keyword sqlkeyword   LOOP MINUS NATURAL NEXTVAL
syn keyword sqlkeyword   OF ON ORDER OUT
syn keyword sqlkeyword   PRIOR RETURN RETURNS REVERSE
syn keyword sqlkeyword   ROWID SELECT
syn keyword sqlkeyword   SQL START STOP SYSDATE
syn keyword sqlkeyword   SYSTIME SYSTIMESTAMP SYSUUID
syn keyword sqlkeyword   TRAILING USING UTCDATE
syn keyword sqlkeyword   UTCTIME UTCTIMESTAMP VALUES
syn keyword sqlkeyword   WHILE
syn keyword sqlkeyword   ANY SOME EXISTS ESCAPE

" IF keywords
syn keyword sqlkeyword	 IF

" CASE keywords
syn keyword sqlKeyword	 WHEN THEN

" Syntax rules common to TEXT and SHORTTEXT keywords
syn keyword sqlKeyword	 LANGUAGE DETECTION LINGUISTIC
syn keyword sqlkeyword   MIME TYPE
syn keyword sqlkeyword   EXACT WEIGHT FUZZY FUZZINESSTHRESHOLD SEARCH
syn keyword sqlkeyword   PHRASE INDEX RATIO REBUILD
syn keyword sqlkeyword   CONFIGURATION
syn keyword sqlkeyword   SEARCH ONLY
syn keyword sqlkeyword   FAST PREPROCESS
syn keyword sqlkeyword   SYNC SYNCHRONOUS ASYNC ASYNCHRONOUS FLUSH QUEUE
syn keyword sqlkeyword   EVERY AFTER MINUTES DOCUMENTS SUSPEND

" Statement keywords (i.e. after ALTER or CREATE)
syn keyword sqlkeyword   AUDIT POLICY
syn keyword sqlkeyword   FULLTEXT
syn keyword sqlkeyword   SEQUENCE RESTART
syn keyword sqlkeyword   TABLE
syn keyword sqlkeyword   PROCEDURE STATISTICS
syn keyword sqlkeyword   SCHEMA
syn keyword sqlkeyword   SYNONYM
syn keyword sqlkeyword   VIEW
syn keyword sqlkeyword   COLUMN
syn keyword sqlkeyword   SYSTEM LICENSE
syn keyword sqlkeyword   SESSION
syn keyword sqlkeyword   CANCEL WORK
syn keyword sqlkeyword   PLAN CACHE
syn keyword sqlkeyword   LOGGING NOLOGGING RETENTION
syn keyword sqlkeyword   RECONFIGURE SERVICE
syn keyword sqlkeyword   RESET MONITORING
syn keyword sqlkeyword   SAVE DURATION PERFTRACE FUNCTION_PROFILER
syn keyword sqlkeyword   SAVEPOINT
syn keyword sqlkeyword   USER
syn keyword sqlkeyword   ROLE
syn keyword sqlkeyword   ASC DESC
syn keyword sqlkeyword   OWNED
syn keyword sqlkeyword   DEPENDENCIES SCRAMBLE

" Create sequence
syn keyword sqlkeyword   INCREMENT MAXVALUE MINVALUE CYCLE

" Create table
syn keyword sqlkeyword   HISTORY GLOBAL LOCAL TEMPORARY

" Create trigger
syn keyword sqlkeyword   TRIGGER REFERENCING EACH DEFAULT
syn keyword sqlkeyword   SIGNAL RESIGNAL MESSAGE_TEXT OLD NEW
syn keyword sqlkeyword   EXIT HANDLER SQL_ERROR_CODE
syn keyword sqlkeyword   TARGET CONDITION SIGNAL

" Alter table
syn keyword sqlkeyword   ADD DROP MODIFY GENERATED ALWAYS
syn keyword sqlkeyword   UNIQUE BTREE CPBTREE PRIMARY KEY
syn keyword sqlkeyword   CONSTRAINT PRELOAD NONE
syn keyword sqlkeyword   ROW THREADS BATCH
syn keyword sqlkeyword   MOVE PARTITION TO LOCATION PHYSICAL OTHERS
syn keyword sqlkeyword   ROUNDROBIN PARTITIONS HASH RANGE VALUE
syn keyword sqlkeyword   PERSISTENT DELTA AUTO AUTOMERGE

" Create audit policy
syn keyword sqlkeyword   AUDITING SUCCESSFUL UNSUCCESSFUL
syn keyword sqlkeyword	 PRIVILEGE STRUCTURED CHANGE LEVEL
syn keyword sqlkeyword	 EMERGENCY ALERT CRITICAL WARNING INFO

" Privileges
syn keyword sqlkeyword   DEBUG EXECUTE

" Schema
syn keyword sqlkeyword   CASCADE RESTRICT PARAMETERS SCAN

" Traces
syn keyword sqlkeyword   CLIENT CRASHDUMP EMERGENCYDUMP
syn keyword sqlkeyword   INDEXSERVER NAMESERVER DAEMON
syn keyword sqlkeyword   CLEAR REMOVE TRACES

" Reclaim
syn keyword sqlkeyword   RECLAIM DATA VOLUME VERSION SPACE DEFRAGMENT SPARSIFY

" Join
syn keyword sqlkeyword   INNER OUTER LEFT RIGHT FULL CROSS JOIN
syn keyword sqlkeyword   GROUPING SETS ROLLUP CUBE
syn keyword sqlkeyword   BEST LIMIT OFFSET
syn keyword sqlkeyword   WITH SUBTOTAL BALANCE TOTAL
syn keyword sqlkeyword   TEXT_FILTER FILL UP SORT MATCHES TOP
syn keyword sqlkeyword   RESULT OVERVIEW PREFIX MULTIPLE RESULTSETS

" Lock
syn keyword sqlkeyword   EXCLUSIVE MODE NOWAIT

" Transaction
syn keyword sqlkeyword   TRANSACTION ISOLATION READ COMMITTED
syn keyword sqlkeyword   REPEATABLE SERIALIZABLE WRITE

" Saml
syn keyword sqlkeyword   SAML ASSERTION PROVIDER SUBJECT ISSUER

" User
syn keyword sqlkeyword   PASSWORD IDENTIFIED EXTERNALLY ATTEMPTS ATTEMPTS
syn keyword sqlkeyword	 ENABLE DISABLE OFF LIFETIME FORCE DEACTIVATE
syn keyword sqlkeyword	 ACTIVATE IDENTITY KERBEROS

" Grant
syn keyword sqlkeyword   ADMIN BACKUP CATALOG SCENARIO INIFILE MONITOR
syn keyword sqlkeyword   OPTIMIZER OPTION
syn keyword sqlkeyword   RESOURCE STRUCTUREDPRIVILEGE TRACE

" Import
syn keyword sqlkeyword   CSV FILE CONTROL NO CHECK SKIP FIRST LIST
syn keyword sqlkeyword	 RECORD DELIMITED FIELD OPTIONALLY ENCLOSED FORMAT

" Roles
syn keyword sqlkeyword   PUBLIC CONTENT_ADMIN MODELING MONITORING

" Miscellaneous
syn keyword sqlkeyword   APPLICATION BINARY IMMEDIATE COREFILE SECURITY DEFINER
syn keyword sqlkeyword   DUMMY INVOKER MATERIALIZED MESSEGE_TEXT PARAMETER PARAMETERS
syn keyword sqlkeyword   PART
syn keyword sqlkeyword   CONSTANT SQLEXCEPTION SQLWARNING

syn keyword sqlOperator  WHERE BETWEEN LIKE NULL CONTAINS
syn keyword sqlOperator  AND OR NOT CASE
syn keyword sqlOperator  UNION INTERSECT EXCEPT

syn keyword sqlStatement ALTER CALL CALLS CREATE DROP RENAME TRUNCATE
syn keyword sqlStatement DELETE INSERT UPDATE EXPLAIN
syn keyword sqlStatement MERGE REPLACE UPSERT SELECT
syn keyword sqlStatement SET UNSET LOAD UNLOAD
syn keyword sqlStatement CONNECT DISCONNECT COMMIT LOCK ROLLBACK
syn keyword sqlStatement GRANT REVOKE
syn keyword sqlStatement EXPORT IMPORT


syn keyword sqlType	 DATE TIME SECONDDATE TIMESTAMP TINYINT SMALLINT
syn keyword sqlType	 INT INTEGER BIGINT SMALLDECIMAL DECIMAL
syn keyword sqlType	 REAL DOUBLE FLOAT
syn keyword sqlType	 VARCHAR NVARCHAR ALPHANUM SHORTTEXT VARBINARY
syn keyword sqlType	 BLOB CLOB NCLOB TEXT DAYDATE

syn keyword sqlOption    Webservice_namespace_host

" Strings and characters:
syn region sqlString		start=+"+    end=+"+ contains=@Spell
syn region sqlString		start=+'+    end=+'+ contains=@Spell

" Numbers:
syn match sqlNumber		"-\=\<\d*\.\=[0-9_]\>"

" Comments:
syn region sqlDashComment	start=/--/ end=/$/ contains=@Spell
syn region sqlSlashComment	start=/\/\// end=/$/ contains=@Spell
syn region sqlMultiComment	start="/\*" end="\*/" contains=sqlMultiComment,@Spell
syn cluster sqlComment	contains=sqlDashComment,sqlSlashComment,sqlMultiComment,@Spell
syn sync ccomment sqlComment
syn sync ccomment sqlDashComment
syn sync ccomment sqlSlashComment

hi def link sqlDashComment	Comment
hi def link sqlSlashComment	Comment
hi def link sqlMultiComment	Comment
hi def link sqlNumber	        Number
hi def link sqlOperator	        Operator
hi def link sqlSpecial	        Special
hi def link sqlKeyword	        Keyword
hi def link sqlStatement	Statement
hi def link sqlString	        String
hi def link sqlType	        Type
hi def link sqlFunction	        Function
hi def link sqlOption	        PreProc

let b:current_syntax = "sqlhana"

" vim:sw=4:
