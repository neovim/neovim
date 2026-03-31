" Vim syntax file
" Language:     mysql
" Maintainer:   Kenneth J. Pronovici <pronovic@ieee.org>
" Filenames:    *.mysql
" URL:          ftp://cedar-solutions.com/software/mysql.vim (https://github.com/pronovic/vim-syntax/blob/master/mysql.vim)
" Note:         The definitions below are taken from the mysql user manual as of April 2002, for version 3.23 and have been updated
"               in July 2024 with the docs for version 8.4
" Last Change:  2016 Apr 11
"  2024-07-21:  update MySQL functions as of MySQL 8.4 (by Vim Project)
" 

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Always ignore case
syn case ignore

" General keywords which don't fall into other categories
syn keyword mysqlKeyword         action add after aggregate all alter as asc auto_increment avg_row_length
syn keyword mysqlKeyword         both by
syn keyword mysqlKeyword         cascade change character check checksum column columns comment constraint create cross
syn keyword mysqlKeyword         current_date current_time current_timestamp
syn keyword mysqlKeyword         data database databases day day_hour day_minute day_second
syn keyword mysqlKeyword         default delayed delay_key_write delete desc describe distinct distinctrow drop
syn keyword mysqlKeyword         enclosed escape escaped explain
syn keyword mysqlKeyword         fields file first flush for foreign from full function
syn keyword mysqlKeyword         global grant grants group
syn keyword mysqlKeyword         having heap high_priority hosts hour hour_minute hour_second
syn keyword mysqlKeyword         identified ignore index infile inner insert insert_id into isam
syn keyword mysqlKeyword         join
syn keyword mysqlKeyword         key keys kill last_insert_id leading left limit lines load local lock logs long
syn keyword mysqlKeyword         low_priority
syn keyword mysqlKeyword         match max_rows middleint min_rows minute minute_second modify month myisam
syn keyword mysqlKeyword         natural no
syn keyword mysqlKeyword         on optimize option optionally order outer outfile
syn keyword mysqlKeyword         pack_keys partial password primary privileges procedure process processlist
syn keyword mysqlKeyword         read references reload rename replace restrict returns revoke right row rows
syn keyword mysqlKeyword         second select show shutdown soname sql_big_result sql_big_selects sql_big_tables sql_log_off
syn keyword mysqlKeyword         sql_log_update sql_low_priority_updates sql_select_limit sql_small_result sql_warnings starting
syn keyword mysqlKeyword         status straight_join string
syn keyword mysqlKeyword         table tables temporary terminated to trailing type
syn keyword mysqlKeyword         unique unlock unsigned update usage use using
syn keyword mysqlKeyword         values varbinary variables varying
syn keyword mysqlKeyword         where with write
syn keyword mysqlKeyword         year_month
syn keyword mysqlKeyword         zerofill

" Special values
syn keyword mysqlSpecial         false null true

" Strings (single- and double-quote)
syn region mysqlString           start=+"+  skip=+\\\\\|\\"+  end=+"+
syn region mysqlString           start=+'+  skip=+\\\\\|\\'+  end=+'+

" Numbers and hexidecimal values
syn match mysqlNumber            "-\=\<[0-9]*\>"
syn match mysqlNumber            "-\=\<[0-9]*\.[0-9]*\>"
syn match mysqlNumber            "-\=\<[0-9][0-9]*e[+-]\=[0-9]*\>"
syn match mysqlNumber            "-\=\<[0-9]*\.[0-9]*e[+-]\=[0-9]*\>"
syn match mysqlNumber            "\<0x[abcdefABCDEF0-9]*\>"

" User variables
syn match mysqlVariable          "@\a*[A-Za-z0-9]*\([._]*[A-Za-z0-9]\)*"

" Escaped column names
syn match mysqlEscaped           "`[^`]*`"

" Comments (c-style, mysql-style and modified sql-style)
syn region mysqlComment          start="/\*"  end="\*/"
syn match mysqlComment           "#.*"
syn match mysqlComment           "--\_s.*"
syn sync ccomment mysqlComment

" Column types
"
" This gets a bit ugly.  There are two different problems we have to
" deal with.
"
" The first problem is that some keywords like 'float' can be used
" both with and without specifiers, i.e. 'float', 'float(1)' and
" 'float(@var)' are all valid.  We have to account for this and we
" also have to make sure that garbage like floatn or float_(1) is not
" highlighted.
"
" The second problem is that some of these keywords are included in
" function names.  For instance, year() is part of the name of the
" dayofyear() function, and the dec keyword (no parenthesis) is part of
" the name of the decode() function.

syn keyword mysqlType            tinyint smallint mediumint int integer bigint
syn keyword mysqlType            date datetime time bit bool
syn keyword mysqlType            tinytext mediumtext longtext text
syn keyword mysqlType            tinyblob mediumblob longblob blob
syn region mysqlType             start="float\W" end="."me=s-1
syn region mysqlType             start="float$" end="."me=s-1
syn region mysqlType             start="\<float(" end=")" contains=mysqlNumber,mysqlVariable
syn region mysqlType             start="double\W" end="."me=s-1
syn region mysqlType             start="double$" end="."me=s-1
syn region mysqlType             start="\<double(" end=")" contains=mysqlNumber,mysqlVariable
syn region mysqlType             start="double precision\W" end="."me=s-1
syn region mysqlType             start="double precision$" end="."me=s-1
syn region mysqlType             start="double precision(" end=")" contains=mysqlNumber,mysqlVariable
syn region mysqlType             start="real\W" end="."me=s-1
syn region mysqlType             start="real$" end="."me=s-1
syn region mysqlType             start="\<real(" end=")" contains=mysqlNumber,mysqlVariable
syn region mysqlType             start="\<numeric(" end=")" contains=mysqlNumber,mysqlVariable
syn region mysqlType             start="dec\W" end="."me=s-1
syn region mysqlType             start="dec$" end="."me=s-1
syn region mysqlType             start="\<dec(" end=")" contains=mysqlNumber,mysqlVariable
syn region mysqlType             start="decimal\W" end="."me=s-1
syn region mysqlType             start="decimal$" end="."me=s-1
syn region mysqlType             start="\<decimal(" end=")" contains=mysqlNumber,mysqlVariable
syn region mysqlType             start="\Wtimestamp\W" end="."me=s-1
syn region mysqlType             start="\Wtimestamp$" end="."me=s-1
syn region mysqlType             start="\Wtimestamp(" end=")" contains=mysqlNumber,mysqlVariable
syn region mysqlType             start="^timestamp\W" end="."me=s-1
syn region mysqlType             start="^timestamp$" end="."me=s-1
syn region mysqlType             start="^timestamp(" end=")" contains=mysqlNumber,mysqlVariable
syn region mysqlType             start="\Wyear(" end=")" contains=mysqlNumber,mysqlVariable
syn region mysqlType             start="^year(" end=")" contains=mysqlNumber,mysqlVariable
syn region mysqlType             start="\<char(" end=")" contains=mysqlNumber,mysqlVariable
syn region mysqlType             start="\<varchar(" end=")" contains=mysqlNumber,mysqlVariable
syn region mysqlType             start="\<enum(" end=")" contains=mysqlString,mysqlVariable
syn region mysqlType             start="\Wset(" end=")" contains=mysqlString,mysqlVariable
syn region mysqlType             start="^set(" end=")" contains=mysqlString,mysqlVariable

" Logical, string and  numeric operators
syn keyword mysqlOperator        between not and or is in like regexp rlike binary exists
syn region mysqlOperatorFunction start="\<isnull(" end=")" contains=ALL
syn region mysqlOperatorFunction start="\<coalesce(" end=")" contains=ALL
syn region mysqlOperatorFunction start="\<interval(" end=")" contains=ALL

" Flow control functions
" https://docs.oracle.com/cd/E17952_01/mysql-8.4-en/flow-control-functions.html
syn keyword mysqlFlowLabel       case when then else end
syn region mysqlFlowFunction     start="\<ifnull("   end=")"  contains=ALL
syn region mysqlFlowFunction     start="\<nullif("   end=")"  contains=ALL
syn region mysqlFlowFunction     start="\<if("       end=")"  contains=ALL

" Window functions
" https://docs.oracle.com/cd/E17952_01/mysql-8.4-en/window-functions-usage.html
syn keyword mysqlWindowKeyword   over partition window
" https://docs.oracle.com/cd/E17952_01/mysql-8.4-en/window-function-descriptions.html
syn region  mysqlWindowFunction  start="\<cume_dist(" end=")" contains=ALL
syn region  mysqlWindowFunction  start="\<dense_rank(" end=")" contains=ALL
syn region  mysqlWindowFunction  start="\<first_value(" end=")" contains=ALL
syn region  mysqlWindowFunction  start="\<lag(" end=")" contains=ALL
syn region  mysqlWindowFunction  start="\<last_value(" end=")" contains=ALL
syn region  mysqlWindowFunction  start="\<lead(" end=")" contains=ALL
syn region  mysqlWindowFunction  start="\<nth_value(" end=")" contains=ALL
syn region  mysqlWindowFunction  start="\<ntile(" end=")" contains=ALL
syn region  mysqlWindowFunction  start="\<percent_rank(" end=")" contains=ALL
syn region  mysqlWindowFunction  start="\<rank(" end=")" contains=ALL
syn region  mysqlWindowFunction  start="\<row_number(" end=")" contains=ALL

" General functions
"
" I'm leery of just defining keywords for functions, since according to the MySQL manual:
"
"     Function names do not clash with table or column names. For example, ABS is a
"     valid column name. The only restriction is that for a function call, no spaces
"     are allowed between the function name and the `(' that follows it.
"
" This means that if I want to highlight function names properly, I have to use a
" region to define them, not just a keyword.  This will probably cause the syntax file
" to load more slowly, but at least it will be 'correct'.

syn region mysqlFunction         start="\<abs(" end=")" contains=ALL
syn region mysqlFunction         start="\<acos(" end=")" contains=ALL
syn region mysqlFunction         start="\<adddate(" end=")" contains=ALL
syn region mysqlFunction         start="\<ascii(" end=")" contains=ALL
syn region mysqlFunction         start="\<asin(" end=")" contains=ALL
syn region mysqlFunction         start="\<atan(" end=")" contains=ALL
syn region mysqlFunction         start="\<atan2(" end=")" contains=ALL
syn region mysqlFunction         start="\<avg(" end=")" contains=ALL
syn region mysqlFunction         start="\<benchmark(" end=")" contains=ALL
syn region mysqlFunction         start="\<bin(" end=")" contains=ALL
syn region mysqlFunction         start="\<bit_and(" end=")" contains=ALL
syn region mysqlFunction         start="\<bit_count(" end=")" contains=ALL
syn region mysqlFunction         start="\<bit_or(" end=")" contains=ALL
syn region mysqlFunction         start="\<ceiling(" end=")" contains=ALL
syn region mysqlFunction         start="\<character_length(" end=")" contains=ALL
syn region mysqlFunction         start="\<char_length(" end=")" contains=ALL
syn region mysqlFunction         start="\<concat(" end=")" contains=ALL
syn region mysqlFunction         start="\<concat_ws(" end=")" contains=ALL
syn region mysqlFunction         start="\<connection_id(" end=")" contains=ALL
syn region mysqlFunction         start="\<conv(" end=")" contains=ALL
syn region mysqlFunction         start="\<cos(" end=")" contains=ALL
syn region mysqlFunction         start="\<cot(" end=")" contains=ALL
syn region mysqlFunction         start="\<count(" end=")" contains=ALL
syn region mysqlFunction         start="\<curdate(" end=")" contains=ALL
syn region mysqlFunction         start="\<curtime(" end=")" contains=ALL
syn region mysqlFunction         start="\<date_add(" end=")" contains=ALL
syn region mysqlFunction         start="\<date_format(" end=")" contains=ALL
syn region mysqlFunction         start="\<date_sub(" end=")" contains=ALL
syn region mysqlFunction         start="\<dayname(" end=")" contains=ALL
syn region mysqlFunction         start="\<dayofmonth(" end=")" contains=ALL
syn region mysqlFunction         start="\<dayofweek(" end=")" contains=ALL
syn region mysqlFunction         start="\<dayofyear(" end=")" contains=ALL
syn region mysqlFunction         start="\<decode(" end=")" contains=ALL
syn region mysqlFunction         start="\<degrees(" end=")" contains=ALL
syn region mysqlFunction         start="\<elt(" end=")" contains=ALL
syn region mysqlFunction         start="\<encode(" end=")" contains=ALL
syn region mysqlFunction         start="\<encrypt(" end=")" contains=ALL
syn region mysqlFunction         start="\<exp(" end=")" contains=ALL
syn region mysqlFunction         start="\<export_set(" end=")" contains=ALL
syn region mysqlFunction         start="\<extract(" end=")" contains=ALL
syn region mysqlFunction         start="\<field(" end=")" contains=ALL
syn region mysqlFunction         start="\<find_in_set(" end=")" contains=ALL
syn region mysqlFunction         start="\<floor(" end=")" contains=ALL
syn region mysqlFunction         start="\<format(" end=")" contains=ALL
syn region mysqlFunction         start="\<from_days(" end=")" contains=ALL
syn region mysqlFunction         start="\<from_unixtime(" end=")" contains=ALL
syn region mysqlFunction         start="\<get_lock(" end=")" contains=ALL
syn region mysqlFunction         start="\<greatest(" end=")" contains=ALL
syn region mysqlFunction         start="\<group_unique_users(" end=")" contains=ALL
syn region mysqlFunction         start="\<hex(" end=")" contains=ALL
syn region mysqlFunction         start="\<inet_aton(" end=")" contains=ALL
syn region mysqlFunction         start="\<inet_ntoa(" end=")" contains=ALL
syn region mysqlFunction         start="\<instr(" end=")" contains=ALL
syn region mysqlFunction         start="\<lcase(" end=")" contains=ALL
syn region mysqlFunction         start="\<least(" end=")" contains=ALL
syn region mysqlFunction         start="\<length(" end=")" contains=ALL
syn region mysqlFunction         start="\<load_file(" end=")" contains=ALL
syn region mysqlFunction         start="\<locate(" end=")" contains=ALL
syn region mysqlFunction         start="\<log(" end=")" contains=ALL
syn region mysqlFunction         start="\<log10(" end=")" contains=ALL
syn region mysqlFunction         start="\<lower(" end=")" contains=ALL
syn region mysqlFunction         start="\<lpad(" end=")" contains=ALL
syn region mysqlFunction         start="\<ltrim(" end=")" contains=ALL
syn region mysqlFunction         start="\<make_set(" end=")" contains=ALL
syn region mysqlFunction         start="\<master_pos_wait(" end=")" contains=ALL
syn region mysqlFunction         start="\<max(" end=")" contains=ALL
syn region mysqlFunction         start="\<md5(" end=")" contains=ALL
syn region mysqlFunction         start="\<mid(" end=")" contains=ALL
syn region mysqlFunction         start="\<min(" end=")" contains=ALL
syn region mysqlFunction         start="\<mod(" end=")" contains=ALL
syn region mysqlFunction         start="\<monthname(" end=")" contains=ALL
syn region mysqlFunction         start="\<now(" end=")" contains=ALL
syn region mysqlFunction         start="\<oct(" end=")" contains=ALL
syn region mysqlFunction         start="\<octet_length(" end=")" contains=ALL
syn region mysqlFunction         start="\<ord(" end=")" contains=ALL
syn region mysqlFunction         start="\<period_add(" end=")" contains=ALL
syn region mysqlFunction         start="\<period_diff(" end=")" contains=ALL
syn region mysqlFunction         start="\<pi(" end=")" contains=ALL
syn region mysqlFunction         start="\<position(" end=")" contains=ALL
syn region mysqlFunction         start="\<pow(" end=")" contains=ALL
syn region mysqlFunction         start="\<power(" end=")" contains=ALL
syn region mysqlFunction         start="\<quarter(" end=")" contains=ALL
syn region mysqlFunction         start="\<radians(" end=")" contains=ALL
syn region mysqlFunction         start="\<rand(" end=")" contains=ALL
syn region mysqlFunction         start="\<release_lock(" end=")" contains=ALL
syn region mysqlFunction         start="\<repeat(" end=")" contains=ALL
syn region mysqlFunction         start="\<reverse(" end=")" contains=ALL
syn region mysqlFunction         start="\<round(" end=")" contains=ALL
syn region mysqlFunction         start="\<rpad(" end=")" contains=ALL
syn region mysqlFunction         start="\<rtrim(" end=")" contains=ALL
syn region mysqlFunction         start="\<sec_to_time(" end=")" contains=ALL
syn region mysqlFunction         start="\<session_user(" end=")" contains=ALL
syn region mysqlFunction         start="\<sign(" end=")" contains=ALL
syn region mysqlFunction         start="\<sin(" end=")" contains=ALL
syn region mysqlFunction         start="\<soundex(" end=")" contains=ALL
syn region mysqlFunction         start="\<space(" end=")" contains=ALL
syn region mysqlFunction         start="\<sqrt(" end=")" contains=ALL
syn region mysqlFunction         start="\<std(" end=")" contains=ALL
syn region mysqlFunction         start="\<stddev(" end=")" contains=ALL
syn region mysqlFunction         start="\<strcmp(" end=")" contains=ALL
syn region mysqlFunction         start="\<subdate(" end=")" contains=ALL
syn region mysqlFunction         start="\<substring(" end=")" contains=ALL
syn region mysqlFunction         start="\<substring_index(" end=")" contains=ALL
syn region mysqlFunction         start="\<subtime(" end=")" contains=ALL
syn region mysqlFunction         start="\<sum(" end=")" contains=ALL
syn region mysqlFunction         start="\<sysdate(" end=")" contains=ALL
syn region mysqlFunction         start="\<system_user(" end=")" contains=ALL
syn region mysqlFunction         start="\<tan(" end=")" contains=ALL
syn region mysqlFunction         start="\<time_format(" end=")" contains=ALL
syn region mysqlFunction         start="\<time_to_sec(" end=")" contains=ALL
syn region mysqlFunction         start="\<to_days(" end=")" contains=ALL
syn region mysqlFunction         start="\<trim(" end=")" contains=ALL
syn region mysqlFunction         start="\<ucase(" end=")" contains=ALL
syn region mysqlFunction         start="\<unique_users(" end=")" contains=ALL
syn region mysqlFunction         start="\<unix_timestamp(" end=")" contains=ALL
syn region mysqlFunction         start="\<upper(" end=")" contains=ALL
syn region mysqlFunction         start="\<user(" end=")" contains=ALL
syn region mysqlFunction         start="\<version(" end=")" contains=ALL
syn region mysqlFunction         start="\<week(" end=")" contains=ALL
syn region mysqlFunction         start="\<weekday(" end=")" contains=ALL
syn region mysqlFunction         start="\<yearweek(" end=")" contains=ALL

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link mysqlKeyword            Keyword
hi def link mysqlSpecial            Special
hi def link mysqlString             String
hi def link mysqlNumber             Number
hi def link mysqlVariable           Identifier
hi def link mysqlComment            Comment
hi def link mysqlType               Type
hi def link mysqlOperator           Operator
hi def link mysqlOperatorFunction   Function
hi def link mysqlFlowFunction       Function
hi def link mysqlFlowLabel          Label
hi def link mysqlWindowFunction     Function
hi def link mysqlWindowKeyword      Keyword
hi def link mysqlFunction           Function


let b:current_syntax = "mysql"

