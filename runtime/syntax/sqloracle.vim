" Vim syntax file
" Language:	SQL, PL/SQL (Oracle 11g)
" Maintainer:	Christian Brabandt
" Repository:   https://github.com/chrisbra/vim-sqloracle-syntax
" License:      Vim
" Previous Maintainer:	Paul Moore
" Last Change:	2016 Jul 22

" Changes:
" 02.04.2016: Support for when keyword
" 03.04.2016: Support for join related keywords
" 22.07.2016: Support Oracle Q-Quote-Syntax

if exists("b:current_syntax")
  finish
endif

syn case ignore

" The SQL reserved words, defined as keywords.

syn keyword sqlSpecial	false null true

syn keyword sqlKeyword	access add as asc begin by case check cluster column
syn keyword sqlKeyword	cache compress connect current cursor decimal default desc
syn keyword sqlKeyword	else elsif end exception exclusive file for from
syn keyword sqlKeyword	function group having identified if immediate increment
syn keyword sqlKeyword	index initial initrans into is level link logging loop
syn keyword sqlKeyword	maxextents maxtrans mode modify monitoring
syn keyword sqlKeyword	nocache nocompress nologging noparallel nowait of offline on online start
syn keyword sqlKeyword	parallel successful synonym table tablespace then to trigger uid
syn keyword sqlKeyword	unique user validate values view when whenever
syn keyword sqlKeyword	where with option order pctfree pctused privileges procedure
syn keyword sqlKeyword	public resource return row rowlabel rownum rows
syn keyword sqlKeyword	session share size smallint type using
syn keyword sqlKeyword	join cross inner outer left right

syn keyword sqlOperator	not and or
syn keyword sqlOperator	in any some all between exists
syn keyword sqlOperator	like escape
syn keyword sqlOperator	union intersect minus
syn keyword sqlOperator	prior distinct
syn keyword sqlOperator	sysdate out

syn keyword sqlStatement analyze audit comment commit
syn keyword sqlStatement delete drop execute explain grant lock noaudit
syn keyword sqlStatement rename revoke rollback savepoint set
syn keyword sqlStatement truncate
" next ones are contained, so folding works.
syn keyword sqlStatement create update alter select insert contained

syn keyword sqlType	boolean char character date float integer long
syn keyword sqlType	mlslabel number raw rowid varchar varchar2 varray

" Strings:
syn region sqlString	matchgroup=Quote start=+"+  skip=+\\\\\|\\"+  end=+"+
syn region sqlString	matchgroup=Quote start=+'+  skip=+\\\\\|\\'+  end=+'+
syn region sqlString	matchgroup=Quote start=+n\?q'\z([^[(<{]\)+    end=+\z1'+
syn region sqlString	matchgroup=Quote start=+n\?q'<+   end=+>'+
syn region sqlString	matchgroup=Quote start=+n\?q'{+   end=+}'+
syn region sqlString	matchgroup=Quote start=+n\?q'(+   end=+)'+
syn region sqlString	matchgroup=Quote start=+n\?q'\[+  end=+]'+

" Numbers:
syn match sqlNumber	"-\=\<\d*\.\=[0-9_]\>"

" Comments:
syn region sqlComment	start="/\*"  end="\*/" contains=sqlTodo,@Spell fold 
syn match sqlComment	"--.*$" contains=sqlTodo,@Spell

" Setup Folding:
" this is a hack, to get certain statements folded.
" the keywords create/update/alter/select/insert need to
" have contained option.
syn region sqlFold start='^\s*\zs\c\(Create\|Update\|Alter\|Select\|Insert\)' end=';$\|^$' transparent fold contains=ALL

syn sync ccomment sqlComment

" Functions:
" (Oracle 11g)
" Aggregate Functions
syn keyword sqlFunction	avg collect corr corr_s corr_k count covar_pop covar_samp cume_dist dense_rank first
syn keyword sqlFunction	group_id grouping grouping_id last max median min percentile_cont percentile_disc percent_rank rank
syn keyword sqlFunction	regr_slope regr_intercept regr_count regr_r2 regr_avgx regr_avgy regr_sxx regr_syy regr_sxy
syn keyword sqlFunction	stats_binomial_test stats_crosstab stats_f_test stats_ks_test stats_mode stats_mw_test
syn keyword sqlFunction	stats_one_way_anova stats_t_test_one stats_t_test_paired stats_t_test_indep stats_t_test_indepu
syn keyword sqlFunction	stats_wsr_test stddev stddev_pop stddev_samp sum
syn keyword sqlFunction	sys_xmlagg var_pop var_samp variance xmlagg
" Char Functions
syn keyword sqlFunction	ascii chr concat initcap instr length lower lpad ltrim
syn keyword sqlFunction	nls_initcap nls_lower nlssort nls_upper regexp_instr regexp_replace
syn keyword sqlFunction	regexp_substr replace rpad rtrim soundex substr translate treat trim upper
" Comparison Functions
syn keyword sqlFunction	greatest least
" Conversion Functions
syn keyword sqlFunction	asciistr bin_to_num cast chartorowid compose convert
syn keyword sqlFunction	decompose hextoraw numtodsinterval numtoyminterval rawtohex rawtonhex rowidtochar
syn keyword sqlFunction	rowidtonchar scn_to_timestamp timestamp_to_scn to_binary_double to_binary_float
syn keyword sqlFunction	to_char to_char to_char to_clob to_date to_dsinterval to_lob to_multi_byte
syn keyword sqlFunction	to_nchar to_nchar to_nchar to_nclob to_number to_dsinterval to_single_byte
syn keyword sqlFunction	to_timestamp to_timestamp_tz to_yminterval to_yminterval translate unistr
" DataMining Functions
syn keyword sqlFunction	cluster_id cluster_probability cluster_set feature_id feature_set
syn keyword sqlFunction	feature_value prediction prediction_bounds prediction_cost
syn keyword sqlFunction	prediction_details prediction_probability prediction_set
" Datetime Functions
syn keyword sqlFunction	add_months current_date current_timestamp dbtimezone extract
syn keyword sqlFunction	from_tz last_day localtimestamp months_between new_time
syn keyword sqlFunction	next_day numtodsinterval numtoyminterval round sessiontimezone
syn keyword sqlFunction	sys_extract_utc sysdate systimestamp to_char to_timestamp
syn keyword sqlFunction	to_timestamp_tz to_dsinterval to_yminterval trunc tz_offset
" Numeric Functions
syn keyword sqlFunction	abs acos asin atan atan2 bitand ceil cos cosh exp
syn keyword sqlFunction	floor ln log mod nanvl power remainder round sign
syn keyword sqlFunction	sin sinh sqrt tan tanh trunc width_bucket
" NLS Functions
syn keyword sqlFunction	ls_charset_decl_len nls_charset_id nls_charset_name
" Various Functions
syn keyword sqlFunction	bfilename cardin coalesce collect decode dump empty_blob empty_clob
syn keyword sqlFunction	lnnvl nullif nvl nvl2 ora_hash powermultiset powermultiset_by_cardinality
syn keyword sqlFunction	sys_connect_by_path sys_context sys_guid sys_typeid uid user userenv vsizeality
" XML Functions
syn keyword sqlFunction	appendchildxml deletexml depth extract existsnode extractvalue insertchildxml
syn keyword sqlFunction	insertxmlbefore path sys_dburigen sys_xmlagg sys_xmlgen updatexml xmlagg xmlcast
syn keyword sqlFunction	xmlcdata xmlcolattval xmlcomment xmlconcat xmldiff xmlelement xmlexists xmlforest
syn keyword sqlFunction	xmlparse xmlpatch xmlpi xmlquery xmlroot xmlsequence xmlserialize xmltable xmltransform
" Todo:
syn keyword sqlTodo TODO FIXME XXX DEBUG NOTE contained

" Define the default highlighting.
hi def link Quote            Special
hi def link sqlComment	Comment
hi def link sqlFunction	Function
hi def link sqlKeyword	sqlSpecial
hi def link sqlNumber	Number
hi def link sqlOperator	sqlStatement
hi def link sqlSpecial	Special
hi def link sqlStatement	Statement
hi def link sqlString	String
hi def link sqlType		Type
hi def link sqlTodo		Todo

let b:current_syntax = "sql"
" vim: ts=8
