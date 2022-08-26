" Vim syntax file
"    Language: SQL*Forms (Oracle 7), based on sql.vim (vim5.0)
"  Maintainer: Austin Ziegler (austin@halostatue.ca)
" Last Change: 2003 May 11
" Prev Change: 19980710
"	  URL: http://www.halostatue.ca/vim/syntax/proc.vim
"
" TODO Find a new maintainer who knows SQL*Forms.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

syntax case ignore

setlocal iskeyword=a-z,A-Z,48-57,_,.,-,>


    " The SQL reserved words, defined as keywords.
syntax match sqlTriggers /on-.*$/
syntax match sqlTriggers /key-.*$/
syntax match sqlTriggers /post-.*$/
syntax match sqlTriggers /pre-.*$/
syntax match sqlTriggers /user-.*$/

syntax keyword sqlSpecial null false true

syntax keyword sqlProcedure abort_query anchor_view bell block_menu break call
syntax keyword sqlProcedure call_input call_query clear_block clear_eol
syntax keyword sqlProcedure clear_field clear_form clear_record commit_form
syntax keyword sqlProcedure copy count_query create_record default_value
syntax keyword sqlProcedure delete_record display_error display_field down
syntax keyword sqlProcedure duplicate_field duplicate_record edit_field
syntax keyword sqlProcedure enter enter_query erase execute_query
syntax keyword sqlProcedure execute_trigger exit_form first_Record go_block
syntax keyword sqlProcedure go_field go_record help hide_menu hide_page host
syntax keyword sqlProcedure last_record list_values lock_record message
syntax keyword sqlProcedure move_view new_form next_block next_field next_key
syntax keyword sqlProcedure next_record next_set pause post previous_block
syntax keyword sqlProcedure previous_field previous_record print redisplay
syntax keyword sqlProcedure replace_menu resize_view scroll_down scroll_up
syntax keyword sqlProcedure set_field show_keys show_menu show_page
syntax keyword sqlProcedure synchronize up user_exit

syntax keyword sqlFunction block_characteristic error_code error_text
syntax keyword sqlFunction error_type field_characteristic form_failure
syntax keyword sqlFunction form_fatal form_success name_in

syntax keyword sqlParameters hide no_hide replace no_replace ask_commit
syntax keyword sqlParameters do_commit no_commit no_validate all_records
syntax keyword sqlParameters for_update no_restrict restrict no_screen
syntax keyword sqlParameters bar full_screen pull_down auto_help auto_skip
syntax keyword sqlParameters fixed_length enterable required echo queryable
syntax keyword sqlParameters updateable update_null upper_case attr_on
syntax keyword sqlParameters attr_off base_table first_field last_field
syntax keyword sqlParameters datatype displayed display_length field_length
syntax keyword sqlParameters list page primary_key query_length x_pos y_pos

syntax match sqlSystem /system\.block_status/
syntax match sqlSystem /system\.current_block/
syntax match sqlSystem /system\.current_field/
syntax match sqlSystem /system\.current_form/
syntax match sqlSystem /system\.current_value/
syntax match sqlSystem /system\.cursor_block/
syntax match sqlSystem /system\.cursor_field/
syntax match sqlSystem /system\.cursor_record/
syntax match sqlSystem /system\.cursor_value/
syntax match sqlSystem /system\.form_status/
syntax match sqlSystem /system\.last_query/
syntax match sqlSystem /system\.last_record/
syntax match sqlSystem /system\.message_level/
syntax match sqlSystem /system\.record_status/
syntax match sqlSystem /system\.trigger_block/
syntax match sqlSystem /system\.trigger_field/
syntax match sqlSystem /system\.trigger_record/
syntax match sqlSystem /\$\$date\$\$/
syntax match sqlSystem /\$\$time\$\$/

syntax keyword sqlKeyword accept access add as asc by check cluster column
syntax keyword sqlKeyword compress connect current decimal default
syntax keyword sqlKeyword desc exclusive file for from group
syntax keyword sqlKeyword having identified immediate increment index
syntax keyword sqlKeyword initial into is level maxextents mode modify
syntax keyword sqlKeyword nocompress nowait of offline on online start
syntax keyword sqlKeyword successful synonym table to trigger uid
syntax keyword sqlKeyword unique user validate values view whenever
syntax keyword sqlKeyword where with option order pctfree privileges
syntax keyword sqlKeyword public resource row rowlabel rownum rows
syntax keyword sqlKeyword session share size smallint sql\*forms_version
syntax keyword sqlKeyword terse define form name title procedure begin
syntax keyword sqlKeyword default_menu_application trigger block field
syntax keyword sqlKeyword enddefine declare exception raise when cursor
syntax keyword sqlKeyword definition base_table pragma
syntax keyword sqlKeyword column_name global trigger_type text description
syntax match sqlKeyword "<<<"
syntax match sqlKeyword ">>>"

syntax keyword sqlOperator not and or out to_number to_date message erase
syntax keyword sqlOperator in any some all between exists substr nvl
syntax keyword sqlOperator exception_init
syntax keyword sqlOperator like escape trunc lpad rpad sum
syntax keyword sqlOperator union intersect minus to_char greatest
syntax keyword sqlOperator prior distinct decode least avg
syntax keyword sqlOperator sysdate true false field_characteristic
syntax keyword sqlOperator display_field call host

syntax keyword sqlStatement alter analyze audit comment commit create
syntax keyword sqlStatement delete drop explain grant insert lock noaudit
syntax keyword sqlStatement rename revoke rollback savepoint select set
syntax keyword sqlStatement truncate update if elsif loop then
syntax keyword sqlStatement open fetch close else end

syntax keyword sqlType char character date long raw mlslabel number rowid
syntax keyword sqlType varchar varchar2 float integer boolean global

syntax keyword sqlCodes sqlcode no_data_found too_many_rows others
syntax keyword sqlCodes form_trigger_failure notfound found
syntax keyword sqlCodes validate no_commit

    " Comments:
syntax region sqlComment    start="/\*"  end="\*/"
syntax match sqlComment  "--.*"

    " Strings and characters:
syntax region sqlString  start=+"+  skip=+\\\\\|\\"+  end=+"+
syntax region sqlString  start=+'+  skip=+\\\\\|\\"+  end=+'+

    " Numbers:
syntax match sqlNumber  "-\=\<[0-9]*\.\=[0-9_]\>"

syntax sync ccomment sqlComment


hi def link sqlComment Comment
hi def link sqlKeyword Statement
hi def link sqlNumber Number
hi def link sqlOperator Statement
hi def link sqlProcedure Statement
hi def link sqlFunction Statement
hi def link sqlSystem Identifier
hi def link sqlSpecial Special
hi def link sqlStatement Statement
hi def link sqlString String
hi def link sqlType Type
hi def link sqlCodes Identifier
hi def link sqlTriggers PreProc


let b:current_syntax = "sqlforms"

" vim: ts=8 sw=4
