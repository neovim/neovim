" Vim syntax file
"    Language: Stored Procedures (STP)
"  Maintainer: Jeff Lanzarotta (jefflanzarotta@yahoo.com)
"	  URL: http://lanzarotta.tripod.com/vim/syntax/stp.vim.zip
" Last Change: March 05, 2002

" For version 5.x, clear all syntax items.
" For version 6.x, quit when a syntax file was already loaded.
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

" Specials.
syn keyword stpSpecial    null

" Keywords.
syn keyword stpKeyword begin break call case create deallocate dynamic
syn keyword stpKeyword execute from function go grant
syn keyword stpKeyword index insert into leave max min on output procedure
syn keyword stpKeyword public result return returns scroll table to
syn keyword stpKeyword when
syn match   stpKeyword "\<end\>"

" Conditional.
syn keyword stpConditional if else elseif then
syn match   stpConditional "\<end\s\+if\>"

" Repeats.
syn keyword stpRepeat for while loop
syn match   stpRepeat "\<end\s\+loop\>"

" Operators.
syn keyword stpOperator asc not and or desc group having in is any some all
syn keyword stpOperator between exists like escape with union intersect minus
syn keyword stpOperator out prior distinct sysdate

" Statements.
syn keyword stpStatement alter analyze as audit avg by close clustered comment
syn keyword stpStatement commit continue count create cursor declare delete
syn keyword stpStatement drop exec execute explain fetch from index insert
syn keyword stpStatement into lock max min next noaudit nonclustered open
syn keyword stpStatement order output print raiserror recompile rename revoke
syn keyword stpStatement rollback savepoint select set sum transaction
syn keyword stpStatement truncate unique update values where

" Functions.
syn keyword stpFunction abs acos ascii asin atan atn2 avg ceiling charindex
syn keyword stpFunction charlength convert col_name col_length cos cot count
syn keyword stpFunction curunreservedpgs datapgs datalength dateadd datediff
syn keyword stpFunction datename datepart db_id db_name degree difference
syn keyword stpFunction exp floor getdate hextoint host_id host_name index_col
syn keyword stpFunction inttohex isnull lct_admin log log10 lower ltrim max
syn keyword stpFunction min now object_id object_name patindex pi pos power
syn keyword stpFunction proc_role radians rand replace replicate reserved_pgs
syn keyword stpFunction reverse right rtrim rowcnt round show_role sign sin
syn keyword stpFunction soundex space sqrt str stuff substr substring sum
syn keyword stpFunction suser_id suser_name tan tsequal upper used_pgs user
syn keyword stpFunction user_id user_name valid_name valid_user message

" Types.
syn keyword stpType binary bit char datetime decimal double float image
syn keyword stpType int integer long money nchar numeric precision real
syn keyword stpType smalldatetime smallint smallmoney text time tinyint
syn keyword stpType timestamp varbinary varchar

" Globals.
syn match stpGlobals '@@char_convert'
syn match stpGlobals '@@cient_csname'
syn match stpGlobals '@@client_csid'
syn match stpGlobals '@@connections'
syn match stpGlobals '@@cpu_busy'
syn match stpGlobals '@@error'
syn match stpGlobals '@@identity'
syn match stpGlobals '@@idle'
syn match stpGlobals '@@io_busy'
syn match stpGlobals '@@isolation'
syn match stpGlobals '@@langid'
syn match stpGlobals '@@language'
syn match stpGlobals '@@max_connections'
syn match stpGlobals '@@maxcharlen'
syn match stpGlobals '@@ncharsize'
syn match stpGlobals '@@nestlevel'
syn match stpGlobals '@@pack_received'
syn match stpGlobals '@@pack_sent'
syn match stpGlobals '@@packet_errors'
syn match stpGlobals '@@procid'
syn match stpGlobals '@@rowcount'
syn match stpGlobals '@@servername'
syn match stpGlobals '@@spid'
syn match stpGlobals '@@sqlstatus'
syn match stpGlobals '@@testts'
syn match stpGlobals '@@textcolid'
syn match stpGlobals '@@textdbid'
syn match stpGlobals '@@textobjid'
syn match stpGlobals '@@textptr'
syn match stpGlobals '@@textsize'
syn match stpGlobals '@@thresh_hysteresis'
syn match stpGlobals '@@timeticks'
syn match stpGlobals '@@total_error'
syn match stpGlobals '@@total_read'
syn match stpGlobals '@@total_write'
syn match stpGlobals '@@tranchained'
syn match stpGlobals '@@trancount'
syn match stpGlobals '@@transtate'
syn match stpGlobals '@@version'

" Todos.
syn keyword stpTodo TODO FIXME XXX DEBUG NOTE

" Strings and characters.
syn match stpStringError "'.*$"
syn match stpString "'\([^']\|''\)*'"

" Numbers.
syn match stpNumber "-\=\<\d*\.\=[0-9_]\>"

" Comments.
syn region stpComment start="/\*" end="\*/" contains=stpTodo
syn match  stpComment "--.*" contains=stpTodo
syn sync   ccomment stpComment

" Parens.
syn region stpParen transparent start='(' end=')' contains=ALLBUT,stpParenError
syn match  stpParenError ")"

" Syntax Synchronizing.
syn sync minlines=10 maxlines=100

" Define the default highlighting.
" For version 5.x and earlier, only when not done already.
" For version 5.8 and later, only when and item doesn't have highlighting yet.
if version >= 508 || !exists("did_stp_syn_inits")
  if version < 508
    let did_stp_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink stpConditional Conditional
  HiLink stpComment Comment
  HiLink stpKeyword Keyword
  HiLink stpNumber Number
  HiLink stpOperator Operator
  HiLink stpSpecial Special
  HiLink stpStatement Statement
  HiLink stpString String
  HiLink stpStringError Error
  HiLink stpType Type
  HiLink stpTodo Todo
  HiLink stpFunction Function
  HiLink stpGlobals Macro
  HiLink stpParen Normal
  HiLink stpParenError Error
  HiLink stpSQLKeyword Function
  HiLink stpRepeat Repeat

  delcommand HiLink
endif

let b:current_syntax = "stp"

" vim ts=8 sw=2
