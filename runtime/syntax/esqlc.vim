" Vim syntax file
" Language:	ESQL-C
" Maintainer:	Jonathan A. George <jageorge@tel.gte.com>
" Last Change:	2001 May 09

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Read the C++ syntax to start with
if version < 600
  source <sfile>:p:h/cpp.vim
else
  runtime! syntax/cpp.vim
endif

" ESQL-C extentions

syntax keyword esqlcPreProc	EXEC SQL INCLUDE

syntax case ignore

syntax keyword esqlcPreProc	begin end declare section database open execute
syntax keyword esqlcPreProc	prepare fetch goto continue found sqlerror work

syntax keyword esqlcKeyword	access add as asc by check cluster column
syntax keyword esqlcKeyword	compress connect current decimal
syntax keyword esqlcKeyword	desc exclusive file from group
syntax keyword esqlcKeyword	having identified immediate increment index
syntax keyword esqlcKeyword	initial into is level maxextents mode modify
syntax keyword esqlcKeyword	nocompress nowait of offline on online start
syntax keyword esqlcKeyword	successful synonym table then to trigger uid
syntax keyword esqlcKeyword	unique user validate values view whenever
syntax keyword esqlcKeyword	where with option order pctfree privileges
syntax keyword esqlcKeyword	public resource row rowlabel rownum rows
syntax keyword esqlcKeyword	session share size smallint

syntax keyword esqlcOperator	not and or
syntax keyword esqlcOperator	in any some all between exists
syntax keyword esqlcOperator	like escape
syntax keyword esqlcOperator	intersect minus
syntax keyword esqlcOperator	prior distinct
syntax keyword esqlcOperator	sysdate

syntax keyword esqlcStatement	alter analyze audit comment commit create
syntax keyword esqlcStatement	delete drop explain grant insert lock noaudit
syntax keyword esqlcStatement	rename revoke rollback savepoint select set
syntax keyword esqlcStatement	truncate update

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_esqlc_syntax_inits")
  if version < 508
    let did_esqlc_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink esqlcOperator	Operator
  HiLink esqlcStatement	Statement
  HiLink esqlcKeyword	esqlcSpecial
  HiLink esqlcSpecial	Special
  HiLink esqlcPreProc	PreProc

  delcommand HiLink
endif

let b:current_syntax = "esqlc"

