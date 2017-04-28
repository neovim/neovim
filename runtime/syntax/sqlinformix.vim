" Vim syntax file
" Informix Structured Query Language (SQL) and Stored Procedure Language (SPL)
" Language:	SQL, SPL (Informix Dynamic Server 2000 v9.2)
" Maintainer:	Dean Hill <dhill@hotmail.com>
" Last Change:	2004 Aug 30

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore



" === Comment syntax group ===
syn region sqlComment    start="{"  end="}" contains=sqlTodo
syn match sqlComment	"--.*$" contains=sqlTodo
syn sync ccomment sqlComment



" === Constant syntax group ===
" = Boolean subgroup =
syn keyword sqlBoolean  true false
syn keyword sqlBoolean  null
syn keyword sqlBoolean  public user
syn keyword sqlBoolean  current today
syn keyword sqlBoolean  year month day hour minute second fraction

" = String subgroup =
syn region sqlString		start=+"+  end=+"+
syn region sqlString		start=+'+  end=+'+

" = Numbers subgroup =
syn match sqlNumber		"-\=\<\d*\.\=[0-9_]\>"



" === Statement syntax group ===
" SQL
syn keyword sqlStatement allocate alter
syn keyword sqlStatement begin
syn keyword sqlStatement close commit connect create
syn keyword sqlStatement database deallocate declare delete describe disconnect drop
syn keyword sqlStatement execute fetch flush free get grant info insert
syn keyword sqlStatement load lock open output
syn keyword sqlStatement prepare put
syn keyword sqlStatement rename revoke rollback select set start stop
syn keyword sqlStatement truncate unload unlock update
syn keyword sqlStatement whenever
" SPL
syn keyword sqlStatement call continue define
syn keyword sqlStatement exit
syn keyword sqlStatement let
syn keyword sqlStatement return system trace

" = Conditional subgroup =
" SPL
syn keyword sqlConditional elif else if then
syn keyword sqlConditional case
" Highlight "end if" with one or more separating spaces
syn match  sqlConditional "end \+if"

" = Repeat subgroup =
" SQL/SPL
" Handle SQL triggers' "for each row" clause and SPL "for" loop
syn match  sqlRepeat "for\( \+each \+row\)\="
" SPL
syn keyword sqlRepeat foreach while
" Highlight "end for", etc. with one or more separating spaces
syn match  sqlRepeat "end \+for"
syn match  sqlRepeat "end \+foreach"
syn match  sqlRepeat "end \+while"

" = Exception subgroup =
" SPL
syn match  sqlException "on \+exception"
syn match  sqlException "end \+exception"
syn match  sqlException "end \+exception \+with \+resume"
syn match  sqlException "raise \+exception"

" = Keyword subgroup =
" SQL
syn keyword sqlKeyword aggregate add as authorization autofree by
syn keyword sqlKeyword cache cascade check cluster collation
syn keyword sqlKeyword column connection constraint cross
syn keyword sqlKeyword dataskip debug default deferred_prepare
syn keyword sqlKeyword descriptor diagnostics
syn keyword sqlKeyword each escape explain external
syn keyword sqlKeyword file foreign fragment from function
syn keyword sqlKeyword group having
syn keyword sqlKeyword immediate index inner into isolation
syn keyword sqlKeyword join key
syn keyword sqlKeyword left level log
syn keyword sqlKeyword mode modify mounting new no
syn keyword sqlKeyword object of old optical option
syn keyword sqlKeyword optimization order outer
syn keyword sqlKeyword pdqpriority pload primary procedure
syn keyword sqlKeyword references referencing release reserve
syn keyword sqlKeyword residency right role routine row
syn keyword sqlKeyword schedule schema scratch session set
syn keyword sqlKeyword statement statistics synonym
syn keyword sqlKeyword table temp temporary timeout to transaction trigger
syn keyword sqlKeyword using values view violations
syn keyword sqlKeyword where with work
" Highlight "on" (if it's not followed by some words we've already handled)
syn match sqlKeyword "on \+\(exception\)\@!"
" SPL
" Highlight "end" (if it's not followed by some words we've already handled)
syn match sqlKeyword "end \+\(if\|for\|foreach\|while\|exception\)\@!"
syn keyword sqlKeyword resume returning

" = Operator subgroup =
" SQL
syn keyword sqlOperator	not and or
syn keyword sqlOperator	in is any some all between exists
syn keyword sqlOperator	like matches
syn keyword sqlOperator union intersect
syn keyword sqlOperator distinct unique



" === Identifier syntax group ===
" = Function subgroup =
" SQL
syn keyword sqlFunction	abs acos asin atan atan2 avg
syn keyword sqlFunction	cardinality cast char_length character_length cos count
syn keyword sqlFunction	exp filetoblob filetoclob hex
syn keyword sqlFunction	initcap length logn log10 lower lpad
syn keyword sqlFunction	min max mod octet_length pow range replace root round rpad
syn keyword sqlFunction	sin sqrt stdev substr substring sum
syn keyword sqlFunction	to_char tan to_date trim trunc upper variance



" === Type syntax group ===
" SQL
syn keyword sqlType	blob boolean byte char character clob
syn keyword sqlType	date datetime dec decimal double
syn keyword sqlType	float int int8 integer interval list lvarchar
syn keyword sqlType	money multiset nchar numeric nvarchar
syn keyword sqlType	real serial serial8 smallfloat smallint
syn keyword sqlType	text varchar varying



" === Todo syntax group ===
syn keyword sqlTodo TODO FIXME XXX DEBUG NOTE



" Define the default highlighting.
" Only when an item doesn't have highlighting yet


" === Comment syntax group ===
hi def link sqlComment	Comment

" === Constant syntax group ===
hi def link sqlNumber	Number
hi def link sqlBoolean	Boolean
hi def link sqlString	String

" === Statment syntax group ===
hi def link sqlStatement	Statement
hi def link sqlConditional	Conditional
hi def link sqlRepeat		Repeat
hi def link sqlKeyword		Keyword
hi def link sqlOperator	Operator
hi def link sqlException	Exception

" === Identifier syntax group ===
hi def link sqlFunction	Function

" === Type syntax group ===
hi def link sqlType	Type

" === Todo syntax group ===
hi def link sqlTodo	Todo


let b:current_syntax = "sqlinformix"
