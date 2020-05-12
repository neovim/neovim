" Vim syntax file
" Language:    N1QL / Couchbase Server
" Maintainer:  Eugene Ciurana <n1ql AT cime.net>
" Version:     1.0
" Source:      https://github.com/pr3d4t0r/n1ql-vim-syntax
"
" License:     Vim is Charityware.  n1ql.vim syntax is Charityware.
"              (c) Copyright 2017 by Eugene Ciurana / pr3d4t0r.  Licensed
"              under the standard VIM LICENSE - Vim command :help uganda.txt
"              for details.
"
" Questions, comments:  <n1ql AT cime.net>
"                       https://ciurana.eu/pgp, https://keybase.io/pr3d4t0r
"
" vim: set fileencoding=utf-8:


if exists("b:current_syntax")
  finish
endif


syn case ignore

syn keyword n1qlSpecial DATASTORES
syn keyword n1qlSpecial DUAL
syn keyword n1qlSpecial FALSE
syn keyword n1qlSpecial INDEXES
syn keyword n1qlSpecial KEYSPACES
syn keyword n1qlSpecial MISSING
syn keyword n1qlSpecial NAMESPACES
syn keyword n1qlSpecial NULL
syn keyword n1qlSpecial TRUE


"
" *** keywords ***
"
syn keyword n1qlKeyword ALL
syn keyword n1qlKeyword ANY
syn keyword n1qlKeyword ASC
syn keyword n1qlKeyword BEGIN
syn keyword n1qlKeyword BETWEEN
syn keyword n1qlKeyword BREAK
syn keyword n1qlKeyword BUCKET
syn keyword n1qlKeyword CALL
syn keyword n1qlKeyword CASE
syn keyword n1qlKeyword CAST
syn keyword n1qlKeyword CLUSTER
syn keyword n1qlKeyword COLLATE
syn keyword n1qlKeyword COLLECTION
syn keyword n1qlKeyword CONNECT
syn keyword n1qlKeyword CONTINUE
syn keyword n1qlKeyword CORRELATE
syn keyword n1qlKeyword COVER
syn keyword n1qlKeyword DATABASE
syn keyword n1qlKeyword DATASET
syn keyword n1qlKeyword DATASTORE
syn keyword n1qlKeyword DECLARE
syn keyword n1qlKeyword DECREMENT
syn keyword n1qlKeyword DERIVED
syn keyword n1qlKeyword DESC
syn keyword n1qlKeyword DESCRIBE
syn keyword n1qlKeyword DO
syn keyword n1qlKeyword EACH
syn keyword n1qlKeyword ELEMENT
syn keyword n1qlKeyword ELSE
syn keyword n1qlKeyword END
syn keyword n1qlKeyword EVERY
syn keyword n1qlKeyword EXCLUDE
syn keyword n1qlKeyword EXISTS
syn keyword n1qlKeyword FETCH
syn keyword n1qlKeyword FIRST
syn keyword n1qlKeyword FLATTEN
syn keyword n1qlKeyword FOR
syn keyword n1qlKeyword FORCE
syn keyword n1qlKeyword FROM
syn keyword n1qlKeyword FUNCTION
syn keyword n1qlKeyword GROUP
syn keyword n1qlKeyword GSI
syn keyword n1qlKeyword HAVING
syn keyword n1qlKeyword IF
syn keyword n1qlKeyword IGNORE
syn keyword n1qlKeyword INCLUDE
syn keyword n1qlKeyword INCREMENT
syn keyword n1qlKeyword INDEX
syn keyword n1qlKeyword INITIAL
syn keyword n1qlKeyword INLINE
syn keyword n1qlKeyword INNER
syn keyword n1qlKeyword INTO
syn keyword n1qlKeyword KEY
syn keyword n1qlKeyword KEYS
syn keyword n1qlKeyword KEYSPACE
syn keyword n1qlKeyword KNOWN
syn keyword n1qlKeyword LAST
syn keyword n1qlKeyword LET
syn keyword n1qlKeyword LETTING
syn keyword n1qlKeyword LIMIT
syn keyword n1qlKeyword LOOP
syn keyword n1qlKeyword LSM
syn keyword n1qlKeyword MAP
syn keyword n1qlKeyword MAPPING
syn keyword n1qlKeyword MATCHED
syn keyword n1qlKeyword MATERIALIZED
syn keyword n1qlKeyword MERGE
syn keyword n1qlKeyword NAMESPACE
syn keyword n1qlKeyword NEST
syn keyword n1qlKeyword OPTION
syn keyword n1qlKeyword ORDER
syn keyword n1qlKeyword OUTER
syn keyword n1qlKeyword OVER
syn keyword n1qlKeyword PARSE
syn keyword n1qlKeyword PARTITION
syn keyword n1qlKeyword PASSWORD
syn keyword n1qlKeyword PATH
syn keyword n1qlKeyword POOL
syn keyword n1qlKeyword PRIMARY
syn keyword n1qlKeyword PRIVATE
syn keyword n1qlKeyword PRIVILEGE
syn keyword n1qlKeyword PROCEDURE
syn keyword n1qlKeyword PUBLIC
syn keyword n1qlKeyword REALM
syn keyword n1qlKeyword REDUCE
syn keyword n1qlKeyword RETURN
syn keyword n1qlKeyword RETURNING
syn keyword n1qlKeyword ROLE
syn keyword n1qlKeyword SATISFIES
syn keyword n1qlKeyword SCHEMA
syn keyword n1qlKeyword SELF
syn keyword n1qlKeyword SEMI
syn keyword n1qlKeyword SHOW
syn keyword n1qlKeyword START
syn keyword n1qlKeyword STATISTICS
syn keyword n1qlKeyword SYSTEM
syn keyword n1qlKeyword THEN
syn keyword n1qlKeyword TRANSACTION
syn keyword n1qlKeyword TRIGGER
syn keyword n1qlKeyword UNDER
syn keyword n1qlKeyword UNKNOWN
syn keyword n1qlKeyword UNSET
syn keyword n1qlKeyword USE
syn keyword n1qlKeyword USER
syn keyword n1qlKeyword USING
syn keyword n1qlKeyword VALIDATE
syn keyword n1qlKeyword VALUE
syn keyword n1qlKeyword VALUED
syn keyword n1qlKeyword VALUES
syn keyword n1qlKeyword VIEW
syn keyword n1qlKeyword WHEN
syn keyword n1qlKeyword WHERE
syn keyword n1qlKeyword WHILE
syn keyword n1qlKeyword WITHIN
syn keyword n1qlKeyword WORK


"
" *** functions ***
"
syn keyword n1qlOperator ABS
syn keyword n1qlOperator ACOS
syn keyword n1qlOperator ARRAY_AGG
syn keyword n1qlOperator ARRAY_APPEND
syn keyword n1qlOperator ARRAY_AVG
syn keyword n1qlOperator ARRAY_CONCAT
syn keyword n1qlOperator ARRAY_CONTAINS
syn keyword n1qlOperator ARRAY_COUNT
syn keyword n1qlOperator ARRAY_DISTINCT
syn keyword n1qlOperator ARRAY_FLATTEN
syn keyword n1qlOperator ARRAY_IFNULL
syn keyword n1qlOperator ARRAY_INSERT
syn keyword n1qlOperator ARRAY_INTERSECT
syn keyword n1qlOperator ARRAY_LENGTH
syn keyword n1qlOperator ARRAY_MAX
syn keyword n1qlOperator ARRAY_MIN
syn keyword n1qlOperator ARRAY_POSITION
syn keyword n1qlOperator ARRAY_PREPEND
syn keyword n1qlOperator ARRAY_PUT
syn keyword n1qlOperator ARRAY_RANGE
syn keyword n1qlOperator ARRAY_REMOVE
syn keyword n1qlOperator ARRAY_REPEAT
syn keyword n1qlOperator ARRAY_REPLACE
syn keyword n1qlOperator ARRAY_REVERSE
syn keyword n1qlOperator ARRAY_SORT
syn keyword n1qlOperator ARRAY_START
syn keyword n1qlOperator ARRAY_SUM
syn keyword n1qlOperator ARRAY_SYMDIFF
syn keyword n1qlOperator ARRAY_UNION
syn keyword n1qlOperator ASIN
syn keyword n1qlOperator ATAN
syn keyword n1qlOperator ATAN2
syn keyword n1qlOperator AVG
syn keyword n1qlOperator BASE64
syn keyword n1qlOperator BASE64_DECODE
syn keyword n1qlOperator BASE64_ENCODE
syn keyword n1qlOperator CEIL
syn keyword n1qlOperator CLOCK_LOCAL
syn keyword n1qlOperator CLOCK_STR
syn keyword n1qlOperator CLOCK_TZ
syn keyword n1qlOperator CLOCK_UTC
syn keyword n1qlOperator CLOCL_MILLIS
syn keyword n1qlOperator CONTAINS
syn keyword n1qlOperator COS
syn keyword n1qlOperator COUNT
syn keyword n1qlOperator DATE_ADD_MILLIS
syn keyword n1qlOperator DATE_ADD_STR
syn keyword n1qlOperator DATE_DIFF_MILLIS
syn keyword n1qlOperator DATE_DIFF_STR
syn keyword n1qlOperator DATE_FORMAT_STR
syn keyword n1qlOperator DATE_PART_MILLIS
syn keyword n1qlOperator DATE_PART_STR
syn keyword n1qlOperator DATE_RANGE_MILLIS
syn keyword n1qlOperator DATE_RANGE_STR
syn keyword n1qlOperator DATE_TRUC_STR
syn keyword n1qlOperator DATE_TRUNC_MILLIS
syn keyword n1qlOperator DECODE_JSON
syn keyword n1qlOperator DEGREES
syn keyword n1qlOperator DURATION_TO_STR
syn keyword n1qlOperator E
syn keyword n1qlOperator ENCODED_SIZE
syn keyword n1qlOperator ENCODE_JSON
syn keyword n1qlOperator EXP
syn keyword n1qlOperator FLOOR
syn keyword n1qlOperator GREATEST
syn keyword n1qlOperator IFINF
syn keyword n1qlOperator IFMISSING
syn keyword n1qlOperator IFMISSINGORNULL
syn keyword n1qlOperator IFNAN
syn keyword n1qlOperator IFNANORINF
syn keyword n1qlOperator IFNULL
syn keyword n1qlOperator INITCAP
syn keyword n1qlOperator ISARRAY
syn keyword n1qlOperator ISATOM
syn keyword n1qlOperator ISBOOLEAN
syn keyword n1qlOperator ISNUMBER
syn keyword n1qlOperator ISOBJECT
syn keyword n1qlOperator ISSTRING
syn keyword n1qlOperator LEAST
syn keyword n1qlOperator LENGTH
syn keyword n1qlOperator LN
syn keyword n1qlOperator LOG
syn keyword n1qlOperator LOWER
syn keyword n1qlOperator LTRIM
syn keyword n1qlOperator MAX
syn keyword n1qlOperator META
syn keyword n1qlOperator MILLIS
syn keyword n1qlOperator MILLIS_TO_LOCAL
syn keyword n1qlOperator MILLIS_TO_STR
syn keyword n1qlOperator MILLIS_TO_TZ
syn keyword n1qlOperator MILLIS_TO_UTC
syn keyword n1qlOperator MILLIS_TO_ZONE_NAME
syn keyword n1qlOperator MIN
syn keyword n1qlOperator MISSINGIF
syn keyword n1qlOperator NANIF
syn keyword n1qlOperator NEGINFIF
syn keyword n1qlOperator NOW_LOCAL
syn keyword n1qlOperator NOW_MILLIS
syn keyword n1qlOperator NOW_STR
syn keyword n1qlOperator NOW_TZ
syn keyword n1qlOperator NOW_UTC
syn keyword n1qlOperator NULLIF
syn keyword n1qlOperator OBJECT_ADD
syn keyword n1qlOperator OBJECT_CONCAT
syn keyword n1qlOperator OBJECT_INNER_PAIRS
syn keyword n1qlOperator OBJECT_INNER_VALUES
syn keyword n1qlOperator OBJECT_LENGTH
syn keyword n1qlOperator OBJECT_NAMES
syn keyword n1qlOperator OBJECT_PAIRS
syn keyword n1qlOperator OBJECT_PUT
syn keyword n1qlOperator OBJECT_REMOVE
syn keyword n1qlOperator OBJECT_RENAME
syn keyword n1qlOperator OBJECT_REPLACE
syn keyword n1qlOperator OBJECT_UNWRAP
syn keyword n1qlOperator OBJECT_VALUES
syn keyword n1qlOperator PI
syn keyword n1qlOperator POLY_LENGTH
syn keyword n1qlOperator POSINIF
syn keyword n1qlOperator POSITION
syn keyword n1qlOperator POWER
syn keyword n1qlOperator RADIANS
syn keyword n1qlOperator RANDOM
syn keyword n1qlOperator REGEXP_CONTAINS
syn keyword n1qlOperator REGEXP_LIKE
syn keyword n1qlOperator REGEXP_POSITION
syn keyword n1qlOperator REGEXP_REPLACE
syn keyword n1qlOperator REPEAT
syn keyword n1qlOperator REPLACE
syn keyword n1qlOperator REVERSE
syn keyword n1qlOperator ROUND
syn keyword n1qlOperator RTRIM
syn keyword n1qlOperator SIGN
syn keyword n1qlOperator SIN
syn keyword n1qlOperator SPLIT
syn keyword n1qlOperator SQRT
syn keyword n1qlOperator STR_TO_DURATION
syn keyword n1qlOperator STR_TO_MILLIS
syn keyword n1qlOperator STR_TO_TZ
syn keyword n1qlOperator STR_TO_UTC
syn keyword n1qlOperator STR_TO_ZONE_NAME
syn keyword n1qlOperator SUBSTR
syn keyword n1qlOperator SUFFIXES
syn keyword n1qlOperator SUM
syn keyword n1qlOperator TAN
syn keyword n1qlOperator TITLE
syn keyword n1qlOperator TOARRAY
syn keyword n1qlOperator TOATOM
syn keyword n1qlOperator TOBOOLEAN
syn keyword n1qlOperator TOKENS
syn keyword n1qlOperator TONUMBER
syn keyword n1qlOperator TOOBJECT
syn keyword n1qlOperator TOSTRING
syn keyword n1qlOperator TRIM
syn keyword n1qlOperator TRUNC
syn keyword n1qlOperator TYPE
syn keyword n1qlOperator UPPER
syn keyword n1qlOperator UUID
syn keyword n1qlOperator WEEKDAY_MILLIS
syn keyword n1qlOperator WEEKDAY_STR


"
" *** operators ***
"
syn keyword n1qlOperator AND
syn keyword n1qlOperator AS
syn keyword n1qlOperator BY
syn keyword n1qlOperator DISTINCT
syn keyword n1qlOperator EXCEPT
syn keyword n1qlOperator ILIKE
syn keyword n1qlOperator IN
syn keyword n1qlOperator INTERSECT
syn keyword n1qlOperator IS
syn keyword n1qlOperator JOIN
syn keyword n1qlOperator LEFT
syn keyword n1qlOperator LIKE
syn keyword n1qlOperator MINUS
syn keyword n1qlOperator NEST
syn keyword n1qlOperator NESTING
syn keyword n1qlOperator NOT
syn keyword n1qlOperator OFFSET
syn keyword n1qlOperator ON
syn keyword n1qlOperator OR
syn keyword n1qlOperator OUT
syn keyword n1qlOperator RIGHT
syn keyword n1qlOperator SOME
syn keyword n1qlOperator TO
syn keyword n1qlOperator UNION
syn keyword n1qlOperator UNIQUE
syn keyword n1qlOperator UNNEST
syn keyword n1qlOperator VIA
syn keyword n1qlOperator WITH
syn keyword n1qlOperator XOR


"
" *** statements ***
"
syn keyword n1qlStatement ALTER
syn keyword n1qlStatement ANALYZE
syn keyword n1qlStatement BUILD
syn keyword n1qlStatement COMMIT
syn keyword n1qlStatement CREATE
syn keyword n1qlStatement DELETE
syn keyword n1qlStatement DROP
syn keyword n1qlStatement EXECUTE
syn keyword n1qlStatement EXPLAIN
syn keyword n1qlStatement GRANT
syn keyword n1qlStatement INFER
syn keyword n1qlStatement INSERT
syn keyword n1qlStatement MERGE
syn keyword n1qlStatement PREPARE
syn keyword n1qlStatement RENAME
syn keyword n1qlStatement REVOKE
syn keyword n1qlStatement ROLLBACK
syn keyword n1qlStatement SELECT
syn keyword n1qlStatement SET
syn keyword n1qlStatement TRUNCATE
syn keyword n1qlStatement UPDATE
syn keyword n1qlStatement UPSERT


"
" *** types ***
"
syn keyword n1qlType ARRAY
syn keyword n1qlType BINARY
syn keyword n1qlType BOOLEAN
syn keyword n1qlType NUMBER
syn keyword n1qlType OBJECT
syn keyword n1qlType RAW
syn keyword n1qlType STRING


"
" *** strings and characters ***
"
syn region n1qlString start=+"+  skip=+\\\\\|\\"+  end=+"+
syn region n1qlString start=+'+  skip=+\\\\\|\\'+  end=+'+
syn region n1qlBucketSpec start=+`+  skip=+\\\\\|\\'+  end=+`+


"
" *** numbers ***
"
syn match n1qlNumber        "-\=\<\d*\.\=[0-9_]\>"


"
" *** comments ***
"
syn region n1qlComment start="/\*"  end="\*/" contains=n1qlTODO
syn match n1qlComment  "--.*$" contains=n1qlTODO
syn sync ccomment      n1qlComment


"
" *** TODO ***
"
syn keyword n1qlTODO contained TODO FIXME XXX DEBUG NOTE


"
" *** enable ***
"
hi def link n1qlBucketSpec Underlined
hi def link n1qlComment    Comment
hi def link n1qlKeyword    Macro
hi def link n1qlOperator   Function
hi def link n1qlSpecial    Special
hi def link n1qlStatement  Statement
hi def link n1qlString     String
hi def link n1qlTODO       Todo
hi def link n1qlType       Type

let b:current_syntax = "n1ql"
