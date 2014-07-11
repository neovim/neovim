" Vim syntax file
" Language:	lite
" Maintainer:	Lutz Eymers <ixtab@polzin.com>
" URL:		http://www.isp.de/data/lite.vim
" Email:	Subject: send syntax_vim.tgz
" Last Change:	2001 Mai 01
"
" Options	lite_sql_query = 1 for SQL syntax highligthing inside strings
"		lite_minlines = x     to sync at least x lines backwards

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'lite'
endif

if main_syntax == 'lite'
  if exists("lite_sql_query")
    if lite_sql_query == 1
      syn include @liteSql <sfile>:p:h/sql.vim
      unlet b:current_syntax
    endif
  endif
endif

if main_syntax == 'msql'
  if exists("msql_sql_query")
    if msql_sql_query == 1
      syn include @liteSql <sfile>:p:h/sql.vim
      unlet b:current_syntax
    endif
  endif
endif

syn cluster liteSql remove=sqlString,sqlComment

syn case match

" Internal Variables
syn keyword liteIntVar ERRMSG contained

" Comment
syn region liteComment		start="/\*" end="\*/" contains=liteTodo

" Function names
syn keyword liteFunctions  echo printf fprintf open close read
syn keyword liteFunctions  readln readtok
syn keyword liteFunctions  split strseg chop tr sub substr
syn keyword liteFunctions  test unlink umask chmod mkdir chdir rmdir
syn keyword liteFunctions  rename truncate link symlink stat
syn keyword liteFunctions  sleep system getpid getppid kill
syn keyword liteFunctions  time ctime time2unixtime unixtime2year
syn keyword liteFunctions  unixtime2year unixtime2month unixtime2day
syn keyword liteFunctions  unixtime2hour unixtime2min unixtime2sec
syn keyword liteFunctions  strftime
syn keyword liteFunctions  getpwnam getpwuid
syn keyword liteFunctions  gethostbyname gethostbyaddress
syn keyword liteFunctions  urlEncode setContentType includeFile
syn keyword liteFunctions  msqlConnect msqlClose msqlSelectDB
syn keyword liteFunctions  msqlQuery msqlStoreResult msqlFreeResult
syn keyword liteFunctions  msqlFetchRow msqlDataSeek msqlListDBs
syn keyword liteFunctions  msqlListTables msqlInitFieldList msqlListField
syn keyword liteFunctions  msqlFieldSeek msqlNumRows msqlEncode
syn keyword liteFunctions  exit fatal typeof
syn keyword liteFunctions  crypt addHttpHeader

" Conditional
syn keyword liteConditional  if else

" Repeat
syn keyword liteRepeat  while

" Operator
syn keyword liteStatement  break return continue

" Operator
syn match liteOperator  "[-+=#*]"
syn match liteOperator  "/[^*]"me=e-1
syn match liteOperator  "\$"
syn match liteRelation  "&&"
syn match liteRelation  "||"
syn match liteRelation  "[!=<>]="
syn match liteRelation  "[<>]"

" Identifier
syn match  liteIdentifier "$\h\w*" contains=liteIntVar,liteOperator
syn match  liteGlobalIdentifier "@\h\w*" contains=liteIntVar

" Include
syn keyword liteInclude  load

" Define
syn keyword liteDefine  funct

" Type
syn keyword liteType  int uint char real

" String
syn region liteString  keepend matchgroup=None start=+"+  skip=+\\\\\|\\"+  end=+"+ contains=liteIdentifier,liteSpecialChar,@liteSql

" Number
syn match liteNumber  "-\=\<\d\+\>"

" Float
syn match liteFloat  "\(-\=\<\d+\|-\=\)\.\d\+\>"

" SpecialChar
syn match liteSpecialChar "\\[abcfnrtv\\]" contained

syn match liteParentError "[)}\]]"

" Todo
syn keyword liteTodo TODO Todo todo contained

" dont syn #!...
syn match liteExec "^#!.*$"

" Parents
syn cluster liteInside contains=liteComment,liteFunctions,liteIdentifier,liteGlobalIdentifier,liteConditional,liteRepeat,liteStatement,liteOperator,liteRelation,liteType,liteString,liteNumber,liteFloat,liteParent

syn region liteParent matchgroup=Delimiter start="(" end=")" contains=@liteInside
syn region liteParent matchgroup=Delimiter start="{" end="}" contains=@liteInside
syn region liteParent matchgroup=Delimiter start="\[" end="\]" contains=@liteInside

" sync
if main_syntax == 'lite'
  if exists("lite_minlines")
    exec "syn sync minlines=" . lite_minlines
  else
    syn sync minlines=100
  endif
endif

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_lite_syn_inits")
  if version < 508
    let did_lite_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink liteComment		Comment
  HiLink liteString		String
  HiLink liteNumber		Number
  HiLink liteFloat		Float
  HiLink liteIdentifier	Identifier
  HiLink liteGlobalIdentifier	Identifier
  HiLink liteIntVar		Identifier
  HiLink liteFunctions		Function
  HiLink liteRepeat		Repeat
  HiLink liteConditional	Conditional
  HiLink liteStatement		Statement
  HiLink liteType		Type
  HiLink liteInclude		Include
  HiLink liteDefine		Define
  HiLink liteSpecialChar	SpecialChar
  HiLink liteParentError	liteError
  HiLink liteError		Error
  HiLink liteTodo		Todo
  HiLink liteOperator		Operator
  HiLink liteRelation		Operator

  delcommand HiLink
endif

let b:current_syntax = "lite"

if main_syntax == 'lite'
  unlet main_syntax
endif

" vim: ts=8
