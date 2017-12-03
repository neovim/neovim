" Vim syntax file
" Language:	lite
" Maintainer:	Lutz Eymers <ixtab@polzin.com>
" URL:		http://www.isp.de/data/lite.vim
" Email:	Subject: send syntax_vim.tgz
" Last Change:	2001 Mai 01
"
" Options	lite_sql_query = 1 for SQL syntax highligthing inside strings
"		lite_minlines = x     to sync at least x lines backwards

" quit when a syntax file was already loaded
if exists("b:current_syntax")
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
" Only when an item doesn't have highlighting yet

hi def link liteComment		Comment
hi def link liteString		String
hi def link liteNumber		Number
hi def link liteFloat		Float
hi def link liteIdentifier	Identifier
hi def link liteGlobalIdentifier	Identifier
hi def link liteIntVar		Identifier
hi def link liteFunctions		Function
hi def link liteRepeat		Repeat
hi def link liteConditional	Conditional
hi def link liteStatement		Statement
hi def link liteType		Type
hi def link liteInclude		Include
hi def link liteDefine		Define
hi def link liteSpecialChar	SpecialChar
hi def link liteParentError	liteError
hi def link liteError		Error
hi def link liteTodo		Todo
hi def link liteOperator		Operator
hi def link liteRelation		Operator


let b:current_syntax = "lite"

if main_syntax == 'lite'
  unlet main_syntax
endif

" vim: ts=8
