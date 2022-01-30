" Vim syntax file
" Language:		BASIC (QuickBASIC 4.5)
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Allan Kelly <allan@fruitloaf.co.uk>
" Contributors:		Thilo Six
" Last Change:		2021 Aug 08

" First version based on Micro$soft QBASIC circa 1989, as documented in
" 'Learn BASIC Now' by Halvorson&Rygmyr. Microsoft Press 1989.
"
" Second version attempts to match Microsoft QuickBASIC 4.5 while keeping FreeBASIC
" (-lang qb) and QB64 (excluding extensions) in mind. -- DJK

" Prelude {{{1
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn iskeyword @,48-57,.,!,#,%,&,$
syn case      ignore

" Whitespace Errors {{{1
if exists("basic_space_errors")
  if !exists("basic_no_trail_space_error")
    syn match basicSpaceError display excludenl "\s\+$"
  endif
  if !exists("basic_no_tab_space_error")
    syn match basicSpaceError display " \+\t"me=e-1
  endif
endif

" Comment Errors {{{1
if !exists("basic_no_comment_errors")
  syn match basicCommentError "\<REM\>.*"
endif

" Not Top Cluster {{{1
syn cluster basicNotTop contains=@basicLineIdentifier,basicDataString,basicDataSeparator,basicTodo

" Statements {{{1

syn cluster basicStatements contains=basicStatement,basicDataStatement,basicMetaRemStatement,basicPutStatement,basicRemStatement

let s:statements =<< trim EOL " {{{2
  beep
  bload
  bsave
  call
  calls
  case
  chain
  chdir
  circle
  clear
  close
  cls
  color
  com
  common
  const
  declare
  def
  def\s\+seg
  defdbl
  defint
  deflng
  defsng
  defstr
  dim
  do
  draw
  elseif
  end
  end\s\+\%(def\|function\|if\|select\|sub\|type\)
  environ
  erase
  error
  exit\s\+\%(def\|do\|for\|function\|sub\)
  field
  files
  for
  function
  get
  gosub
  goto
  if
  input
  ioctl
  key
  kill
  let
  line
  line\s\+input
  locate
  lock
  loop
  lprint
  lset
  mkdir
  name
  next
  on
  on\s\+error
  on\s\+uevent
  open
  open\s\+com
  option
  out
  paint
  palette
  palette\s\+using
  pcopy
  pen
  pmap
  poke
  preset
  print
  pset
  randomize
  read
  redim
  reset
  restore
  resume
  return
  rmdir
  rset
  run
  select\s\+case
  shared
  shell
  sleep
  sound
  static
  stop
  strig
  sub
  swap
  system
  troff
  tron
  type
  uevent
  unlock
  using
  view
  view\s\+print
  wait
  wend
  while
  width
  window
  write
EOL
" }}}

for s in s:statements
  exe 'syn match basicStatement "\<' .. s .. '\>" contained'
endfor

syn match basicStatement "\<\%(then\|else\)\>" nextgroup=@basicStatements skipwhite

" DATA Statement
syn match  basicDataSeparator "," contained
syn region basicDataStatement matchgroup=basicStatement start="\<data\>" matchgroup=basicStatementSeparator end=":\|$" contained contains=basicDataSeparator,basicDataString,basicNumber,basicFloat,basicString

if !exists("basic_no_data_fold")
  syn region basicMultilineData start="^\s*\<data\>.*\n\%(^\s*\<data\>\)\@=" end="^\s*\<data\>.*\n\%(^\s*\<data\>\)\@!" contains=basicDataStatement transparent fold keepend
endif

" PUT File I/O and Graphics statements - needs special handling for graphics
" action verbs
syn match  basicPutAction "\<\%(pset\|preset\|and\|or\|xor\)\>" contained
syn region basicPutStatement matchgroup=basicStatement start="\<put\>" matchgroup=basicStatementSeparator end=":\|$" contained contains=basicKeyword,basicPutAction,basicFilenumber

" Keywords {{{1
let s:keywords =<< trim EOL " {{{2
  absolute
  access
  alias
  append
  as
  base
  binary
  byval
  cdecl
  com
  def
  do
  for
  function
  gosub
  goto
  input
  int86old
  int86xold
  interrupt
  interruptx
  is
  key
  len
  list
  local
  lock
  lprint
  next
  off
  on
  output
  pen
  play
  random
  read
  resume
  screen
  seg
  shared
  signal
  static
  step
  stop
  strig
  sub
  timer
  to
  until
  using
  while
  write
EOL
" }}}

for k in s:keywords
  exe 'syn match basicKeyword "\<' .. k .. '\>"'
endfor

" Functions {{{1
syn keyword basicFunction abs asc atn cdbl chr$ cint clng command$ cos csng
syn keyword basicFunction csrlin cvd cvdmbf cvi cvl cvs cvsmbf environ$ eof
syn keyword basicFunction erdev erdev$ erl err exp fileattr fix fre freefile
syn keyword basicFunction hex$ inkey$ inp input$ instr int ioctl$ left$ lbound
syn keyword basicFunction lcase$ len loc lof log lpos ltrim$ mkd$ mkdmbf$ mki$
syn keyword basicFunction mkl$ mks$ mksmbf$ oct$ peek pen point pos right$ rnd
syn keyword basicFunction rtrim$ sadd setmem sgn sin space$ spc sqr stick str$
syn keyword basicFunction strig string$ tab tan ubound ucase$ val valptr
syn keyword basicFunction valseg varptr varptr$ varseg

" Functions and statements (same name) {{{1
syn match   basicStatement "\<\%(date\$\|mid\$\|play\|screen\|seek\|time\$\|timer\)\>" contained
syn match   basicFunction  "\<\%(date\$\|mid\$\|play\|screen\|seek\|time\$\|timer\)\>"

" Types {{{1
syn keyword basicType integer long single double string any

" Strings {{{1

" Unquoted DATA strings - anything except [:,] and leading or trailing whitespace
" Needs lower priority than numbers
syn match basicDataString "[^[:space:],:]\+\%(\s\+[^[:space:],:]\+\)*" contained

syn region basicString start=+"+ end=+"+ oneline

" Booleans {{{1
if exists("basic_booleans")
  syn keyword basicBoolean true false
endif

" Numbers {{{1

" Integers
syn match basicNumber "-\=&o\=\o\+[%&]\=\>"
syn match basicNumber "-\=&h\x\+[%&]\=\>"
syn match basicNumber "-\=\<\d\+[%&]\=\>"

" Floats
syn match basicFloat "-\=\<\d\+\.\=\d*\%(\%([ed][+-]\=\d*\)\|[!#]\)\=\>"
syn match basicFloat      "-\=\<\.\d\+\%(\%([ed][+-]\=\d*\)\|[!#]\)\=\>"

" Statement anchors {{{1
syn match basicLineStart	  "^" nextgroup=@basicStatements,@basicLineIdentifier skipwhite
syn match basicStatementSeparator ":" nextgroup=@basicStatements		      skipwhite

" Line numbers and labels {{{1

" QuickBASIC limits these to 65,529 and 40 chars respectively
syn match basicLineNumber "\d\+"		  nextgroup=@basicStatements skipwhite contained
syn match basicLineLabel  "\a[[:alnum:]]*\ze\s*:" nextgroup=@basicStatements skipwhite contained

syn cluster basicLineIdentifier contains=basicLineNumber,basicLineLabel

" Line Continuation {{{1
syn match basicLineContinuation "\s*\zs_\ze\s*$"

" Type suffixes {{{1
if exists("basic_type_suffixes")
  syn match basicTypeSuffix "\a[[:alnum:].]*\zs[$%&!#]"
endif

" File numbers {{{1
syn match basicFilenumber "#\d\+"
syn match basicFilenumber "#\a[[:alnum:].]*[%&!#]\="

" Operators {{{1
if exists("basic_operators")
  syn match basicArithmeticOperator "[-+*/\\^]"
  syn match basicRelationalOperator "<>\|<=\|>=\|[><=]"
endif
syn match basicLogicalOperator	  "\<\%(not\|and\|or\|xor\|eqv\|imp\)\>"
syn match basicArithmeticOperator "\<mod\>"

" Metacommands {{{1
" Note: No trailing word boundaries.  Text may be freely mixed however there
" must be only leading whitespace prior to the first metacommand
syn match basicMetacommand "$INCLUDE\s*:\s*'[^']\+'" contained containedin=@basicMetaComments
syn match basicMetacommand "$\%(DYNAMIC\|STATIC\)"   contained containedin=@basicMetaComments

" Comments {{{1
syn keyword basicTodo TODO FIXME XXX NOTE contained

syn region basicRemStatement matchgroup=basicStatement start="REM\>" end="$" contains=basicTodo,@Spell contained
syn region basicComment				       start="'"     end="$" contains=basicTodo,@Spell

if !exists("basic_no_comment_fold")
  syn region basicMultilineComment start="^\s*'.*\n\%(\s*'\)\@=" end="^\s*'.*\n\%(\s*'\)\@!" contains=@basicComments transparent fold keepend
endif

" Metacommands
syn region  basicMetaRemStatement matchgroup=basicStatement start="REM\>\s*\$\@=" end="$" contains=basicTodo contained
syn region  basicMetaComment				    start="'\s*\$\@="	  end="$" contains=basicTodo

syn cluster basicMetaComments contains=basicMetaComment,basicMetaRemStatement
syn cluster basicComments     contains=basicComment,basicMetaComment

"syn sync ccomment basicComment

" Default Highlighting {{{1
hi def link basicArithmeticOperator basicOperator
hi def link basicBoolean	    Boolean
hi def link basicComment	    Comment
hi def link basicCommentError	    Error
hi def link basicDataString	    basicString
hi def link basicFilenumber	    basicTypeSuffix " TODO: better group
hi def link basicFloat		    Float
hi def link basicFunction	    Identifier
hi def link basicKeyword	    Keyword
hi def link basicLineIdentifier	    LineNr
hi def link basicLineContinuation   Special
hi def link basicLineLabel	    basicLineIdentifier
hi def link basicLineNumber	    basicLineIdentifier
hi def link basicLogicalOperator    basicOperator
hi def link basicMetacommand	    SpecialComment
hi def link basicMetaComment	    Comment
hi def link basicMetaRemStatement   Comment
hi def link basicNumber		    Number
hi def link basicOperator	    Operator
hi def link basicPutAction	    Keyword
hi def link basicRelationalOperator basicOperator
hi def link basicRemStatement	    Comment
hi def link basicSpaceError	    Error
hi def link basicStatementSeparator Special
hi def link basicStatement	    Statement
hi def link basicString		    String
hi def link basicTodo		    Todo
hi def link basicType		    Type
hi def link basicTypeSuffix	    Special
if exists("basic_legacy_syntax_groups")
  hi def link basicTypeSpecifier      Type
  hi def link basicTypeSuffix	      basicTypeSpecifier
endif

" Postscript {{{1
let b:current_syntax = "basic"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
