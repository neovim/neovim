" Vim syntax file
" Language:     Data Analysis Expressions (DAX)
" Maintainer:   Anarion Dunedain <anarion80@gmail.com>
" Last Change:
"   2025 Mar 28  First version

" quit when a syntax file was already loaded
if exists("b:current_syntax")
        finish
endif
let s:keepcpo = &cpo
set cpo&vim

" There are DAX functions with dot in the name (like VARX.S)
setlocal iskeyword+=.
" DAX is case insensitive
syn case ignore

" DAX statements
syn keyword daxStatement DEFINE EVALUATE MEASURE RETURN VAR
syn match daxStatement "ORDER\ BY"
syn match daxStatement "START\ AT"

" TODO
syn keyword daxTodo FIXME NOTE TODO OPTIMIZE XXX HACK contained

" DAX functions
syn keyword daxFunction
  \ ABS ACCRINT ACCRINTM ACOS ACOSH ACOT ACOTH
  \ ADDCOLUMNS ADDMISSINGITEMS ALL ALLCROSSFILTERED ALLEXCEPT ALLNOBLANKROW ALLSELECTED
  \ AMORDEGRC AMORLINC AND APPROXIMATEDISTINCTCOUNT ASIN ASINH ATAN
  \ ATANH AVERAGE AVERAGEA AVERAGEX BETA.DIST BETA.INV BITAND
  \ BITLSHIFT BITOR BITRSHIFT BITXOR BLANK CALCULATE CALCULATETABLE
  \ CALENDAR CALENDARAUTO CEILING CHISQ.DIST CHISQ.DIST.RT CHISQ.INV CHISQ.INV.RT
  \ CLOSINGBALANCEMONTH CLOSINGBALANCEQUARTER CLOSINGBALANCEYEAR COALESCE COLUMNSTATISTICS COMBIN COMBINA
  \ COMBINEVALUES CONCATENATE CONCATENATEX CONFIDENCE.NORM CONFIDENCE.T CONTAINSROW
  \ CONTAINSSTRING CONTAINSSTRINGEXACT CONVERT COS COSH COT COTH
  \ COUNT COUNTA COUNTAX COUNTBLANK COUNTROWS COUNTX COUPDAYBS
  \ COUPDAYS COUPDAYSNC COUPNCD COUPNUM COUPPCD CROSSFILTER CROSSJOIN
  \ CUMIPMT CUMPRINC CURRENCY CURRENTGROUP CUSTOMDATA DATATABLE DATE
  \ DATEADD DATEDIFF DATESBETWEEN DATESINPERIOD DATESMTD DATESQTD DATESYTD
  \ DATEVALUE DAY DB DDB DEGREES DETAILROWS DISC
  \ DISTINCT column DISTINCT table DISTINCTCOUNT DISTINCTCOUNTNOBLANK DIVIDE DOLLARDE DOLLARFR
  \ DURATION EARLIER EARLIEST EDATE EFFECT ENDOFMONTH ENDOFQUARTER
  \ ENDOFYEAR EOMONTH ERROR EVALUATEANDLOG EVEN EXACT EXCEPT
  \ EXP EXPON.DIST FACT FALSE FILTER FILTERS FIND
  \ FIRST FIRSTDATE FIXED FLOOR FORMAT FV GCD
  \ GENERATE GENERATEALL GENERATESERIES GEOMEAN GEOMEANX GROUPBY HASONEFILTER
  \ HASONEVALUE HOUR IF IF.EAGER IFERROR IGNORE INDEX
  \ INFO.ALTERNATEOFDEFINITIONS INFO.ANNOTATIONS INFO.ATTRIBUTEHIERARCHIES INFO.ATTRIBUTEHIERARCHYSTORAGES INFO.CALCDEPENDENCY INFO.CALCULATIONGROUPS INFO.CALCULATIONITEMS
  \ INFO.CATALOGS INFO.CHANGEDPROPERTIES INFO.COLUMNPARTITIONSTORAGES INFO.COLUMNPERMISSIONS INFO.COLUMNS INFO.COLUMNSTORAGES INFO.CSDLMETADATA
  \ INFO.CULTURES INFO.DATACOVERAGEDEFINITIONS INFO.DATASOURCES INFO.DELTATABLEMETADATASTORAGES INFO.DEPENDENCIES INFO.DETAILROWSDEFINITIONS INFO.DICTIONARYSTORAGES
  \ INFO.EXCLUDEDARTIFACTS INFO.EXPRESSIONS INFO.EXTENDEDPROPERTIES INFO.FORMATSTRINGDEFINITIONS INFO.FUNCTIONS INFO.GENERALSEGMENTMAPSEGMENTMETADATASTORAGES INFO.GROUPBYCOLUMNS
  \ INFO.HIERARCHIES INFO.HIERARCHYSTORAGES INFO.KPIS INFO.LEVELS INFO.LINGUISTICMETADATA INFO.MEASURES INFO.MODEL
  \ INFO.OBJECTTRANSLATIONS INFO.PARQUETFILESTORAGES INFO.PARTITIONS INFO.PARTITIONSTORAGES INFO.PERSPECTIVECOLUMNS INFO.PERSPECTIVEHIERARCHIES INFO.PERSPECTIVEMEASURES
  \ INFO.PERSPECTIVES INFO.PERSPECTIVETABLES INFO.PROPERTIES INFO.QUERYGROUPS INFO.REFRESHPOLICIES INFO.RELATEDCOLUMNDETAILS INFO.RELATIONSHIPINDEXSTORAGES
  \ INFO.RELATIONSHIPS INFO.RELATIONSHIPSTORAGES INFO.ROLEMEMBERSHIPS INFO.ROLES INFO.SEGMENTMAPSTORAGES INFO.SEGMENTSTORAGES INFO.STORAGEFILES
  \ INFO.STORAGEFOLDERS INFO.STORAGETABLECOLUMNS INFO.STORAGETABLECOLUMNSEGMENTS INFO.STORAGETABLES INFO.TABLEPERMISSIONS INFO.TABLES INFO.TABLESTORAGES
  \ INFO.VARIATIONS INFO.VIEW.COLUMNS INFO.VIEW.MEASURES INFO.VIEW.RELATIONSHIPS INFO.VIEW.TABLES INT INTERSECT
  \ INTRATE IPMT ISAFTER ISBLANK ISCROSSFILTERED ISEMPTY ISERROR
  \ ISEVEN ISFILTERED ISINSCOPE ISLOGICAL ISNONTEXT ISNUMBER ISO.CEILING
  \ ISODD ISONORAFTER ISPMT ISSELECTEDMEASURE ISSUBTOTAL ISTEXT KEEPFILTERS
  \ LAST LASTDATE LCM LEFT LEN LINEST LINESTX
  \ LN LOG LOG10 LOOKUPVALUE LOWER MATCHBY MAX
  \ MAXA MAXX MDURATION MEDIAN MEDIANX MID MIN
  \ MINA MINUTE MINX MOD MONTH MOVINGAVERAGE MROUND
  \ NATURALINNERJOIN NATURALLEFTOUTERJOIN NETWORKDAYS NEXT NEXTDAY NEXTMONTH NEXTQUARTER
  \ NEXTYEAR NOMINAL NONVISUAL NORM.DIST NORM.INV NORM.S.DIST NORM.S.INV
  \ NOT NOW NPER ODD ODDFPRICE ODDFYIELD ODDLPRICE
  \ ODDLYIELD OFFSET OPENINGBALANCEMONTH OPENINGBALANCEQUARTER OPENINGBALANCEYEAR OR ORDERBY
  \ PARALLELPERIOD PARTITIONBY PATH PATHCONTAINS PATHITEM PATHITEMREVERSE PATHLENGTH
  \ PDURATION PERCENTILE.EXC PERCENTILE.INC PERCENTILEX.EXC PERCENTILEX.INC PERMUT PI
  \ PMT POISSON.DIST POWER PPMT PREVIOUS PREVIOUSDAY PREVIOUSMONTH
  \ PREVIOUSQUARTER PREVIOUSYEAR PRICE PRICEDISC PRICEMAT PRODUCT PRODUCTX
  \ PV QUARTER QUOTIENT RADIANS RAND RANDBETWEEN RANGE
  \ RANK RANK.EQ RANKX RATE RECEIVED RELATED RELATEDTABLE
  \ REMOVEFILTERS REPLACE REPT RIGHT ROLLUP ROLLUPADDISSUBTOTAL ROLLUPGROUP
  \ ROLLUPISSUBTOTAL ROUND ROUNDDOWN ROUNDUP ROW ROWNUMBER RRI
  \ RUNNINGSUM SAMEPERIODLASTYEAR SAMPLE SEARCH SECOND SELECTCOLUMNS SELECTEDMEASURE
  \ SELECTEDMEASUREFORMATSTRING SELECTEDMEASURENAME SELECTEDVALUE SIGN SIN SINH SLN
  \ SQRT SQRTPI STARTOFMONTH STARTOFQUARTER STARTOFYEAR STDEV.P STDEV.S
  \ STDEVX.P STDEVX.S SUBSTITUTE SUBSTITUTEWITHINDEX SUM SUMMARIZE SUMMARIZECOLUMNS
  \ SUMX SWITCH SYD T.DIST T.DIST.2T T.DIST.RT T.INV
  \ T.INV.2t TAN TANH TBILLEQ TBILLPRICE TBILLYIELD TIME
  \ TIMEVALUE TOCSV TODAY TOJSON TOPN TOTALMTD TOTALQTD
  \ TOTALYTD TREATAS TRIM TRUE TRUNC Table Constructor UNICHAR
  \ UNICODE UNION UPPER USERCULTURE USERELATIONSHIP USERNAME USEROBJECTID
  \ USERPRINCIPALNAME UTCNOW UTCTODAY VALUE VALUES VAR.P VAR.S
  \ VARX.P VARX.S VDB WEEKDAY WEEKNUM WINDOW XIRR
  \ XNPV YEAR YEARFRAC YIELD YIELDDISC YIELDMAT

" CONTAINS is a vim syntax keyword and can't be a defined keyword
syn match daxFunction "CONTAINS"

" Numbers
" integer number, or floating point number without a dot.
syn match daxNumber "\<\d\+\>"
" floating point number, with dot
syn match daxNumber "\<\d\+\.\d*\>"

syn match daxFloat "[-+]\=\<\d\+[eE][\-+]\=\d\+"
syn match daxFloat "[-+]\=\<\d\+\.\d*\([eE][\-+]\=\d\+\)\="
syn match daxFloat "[-+]\=\<\.\d\+\([eE][\-+]\=\d\+\)\="

" String and Character constants
syn region daxString start=+"+  end=+"+

" DAX Table and Column names
syn region daxTable start=+'+ms=s+1  end=+'+me=e-1
syn region daxColumn matchgroup=daxParen start=/\[/ end=/\]/

" Operators
syn match daxOperator "+"
syn match daxOperator "-"
syn match daxOperator "*"
syn match daxOperator "/"
syn match daxOperator "\^"
syn match daxOperator "\ NOT(\s\|\\)"
syn match daxOperator "\ IN\ "
syn match daxOperator "&&"
syn match daxOperator "&"
syn match daxOperator "\\|\\|"
syn match daxOperator "[<>]=\="
syn match daxOperator "<>"
syn match daxOperator "="
syn match daxOperator ">"
syn match daxOperator "<"

" Comments
syn region daxComment start="\(^\|\s\)\//"   end="$" contains=daxTodo
syn region daxComment start="/\*"  end="\*/" contains=daxTodo

" Define highlighting
hi def link daxComment          Comment
hi def link daxNumber           Number
hi def link daxFloat            Float
hi def link daxString           String
hi def link daxStatement        Keyword
hi def link daxOperator         Operator
hi def link daxFunction         Function
hi def link daxTable            Number
hi def link daxColumn           Statement
hi def link daxParen            Delimiter
hi def link daxTodo             Todo

let b:current_syntax = "dax"

let &cpo = s:keepcpo
unlet! s:keepcpo

" vim: ts=8
