" Vim syntax file
" Language:     PRQL
" Maintainer:   vanillajonathan
" Last Change:  2025-03-07
"
" https://prql-lang.org/
" https://github.com/PRQL/prql

" quit when a syntax file was already loaded.
if exists("b:current_syntax")
  finish
endif

" We need nocompatible mode in order to continue lines with backslashes.
" Original setting will be restored.
let s:cpo_save = &cpo
set cpo&vim

syn keyword prqlBoolean      false true
syn keyword prqlSelf         this that
syn keyword prqlStatement    null
syn keyword prqlConditional  case
syn keyword prqlStatement    prql let type alias in
syn keyword prqlRepeat       loop
syn match   prqlOperator     display "\%(+\|-\|/\|*\|=\|\^\|&\||\|!\|>\|<\|%\|\~\)=\?"
syn match   prqlOperator     display "&&\|||"
syn keyword prqlInclude      module

" Annotations
syn match   prqlAnnotation  "@" display contained
syn match   prqlAnnotationName  "@\s*{\h\%(\w\|=\)*}" display contains=prqlAnnotation

syn match   prqlFunction  "\h\w*" display contained

syn match   prqlComment  "#.*$" contains=prqlTodo,@Spell
syn keyword prqlTodo    FIXME NOTE TODO XXX contained

" Triple-quoted strings can contain doctests.
syn region  prqlString matchgroup=prqlQuotes
      \ start=+\z(['"]\)+ end="\z1" skip="\\\\\|\\\z1"
      \ contains=prqlEscape,@Spell
syn region  prqlString matchgroup=prqlTripleQuotes
      \ start=+\z('''\|"""\)+ end="\z1" keepend
      \ contains=prqlEscape,prqlSpaceError,prqlDoctest,@Spell
syn region  prqlFString matchgroup=prqlQuotes
      \ start=+[f]\z(['"]\)+ end="\z1" skip="\\\\\|\\\z1"
      \ contains=prqlEscape,@Spell
syn region  prqlFString matchgroup=prqlTripleQuotes
      \ start=+f\z('''\|"""\)+ end="\z1" keepend
      \ contains=prqlEscape,prqlSpaceError,prqlDoctest,@Spell
syn region  prqlRString matchgroup=prqlQuotes
      \ start=+r\z(['"]\)+ end="\z1" skip="\\\\\|\\\z1"
      \ contains=@Spell
syn region  prqlRString matchgroup=prqlTripleQuotes
      \ start=+r\z('''\|"""\)+ end="\z1" keepend
      \ contains=prqlSpaceError,prqlDoctest,@Spell
syn region  prqlSString matchgroup=prqlQuotes
      \ start=+s\z(['"]\)+ end="\z1" skip="\\\\\|\\\z1"
      \ contains=@Spell
syn region  prqlSString matchgroup=prqlTripleQuotes
      \ start=+s\z('''\|"""\)+ end="\z1" keepend
      \ contains=prqlSpaceError,prqlDoctest,@Spell

syn match   prqlEscape  +\\[bfnrt'"\\]+ contained
syn match   prqlEscape  "\\\o\{1,3}" contained
syn match   prqlEscape  "\\x\x\{2}" contained
syn match   prqlEscape  "\%(\\u\x\{1,6}\)" contained
syn match   prqlEscape  "\\$"

" It is very important to understand all details before changing the
" regular expressions below or their order.
" The word boundaries are *not* the floating-point number boundaries
" because of a possible leading or trailing decimal point.
" The expressions below ensure that all valid number literals are
" highlighted, and invalid number literals are not.  For example,
"
" - a decimal point in '4.' at the end of a line is highlighted,
" - a second dot in 1.0.0 is not highlighted,
" - 08 is not highlighted,
" - 08e0 or 08j are highlighted,
"
if !exists("prql_no_number_highlight")
  " numbers (including complex)
  syn match   prqlNumber  "\<0[oO]\%(_\=\o\)\+\>"
  syn match   prqlNumber  "\<0[xX]\%(_\=\x\)\+\>"
  syn match   prqlNumber  "\<0[bB]\%(_\=[01]\)\+\>"
  syn match   prqlNumber  "\<\%([1-9]\%(_\=\d\)*\|0\+\%(_\=0\)*\)\>"
  syn match   prqlNumber  "\<\d\%(_\=\d\)*[jJ]\>"
  syn match   prqlNumber  "\<\d\%(_\=\d\)*[eE][+-]\=\d\%(_\=\d\)*[jJ]\=\>"
  syn match   prqlNumber
        \ "\<\d\%(_\=\d\)*\.\%([eE][+-]\=\d\%(_\=\d\)*\)\=[jJ]\=\%(\W\|$\)\@="
  syn match   prqlNumber
        \ "\%(^\|\W\)\zs\%(\d\%(_\=\d\)*\)\=\.\d\%(_\=\d\)*\%([eE][+-]\=\d\%(_\=\d\)*\)\=[jJ]\=\>"
endif

" https://prql-lang.org/book/reference/stdlib/transforms/
"
" PRQL built-in functions are in alphabetical order.
"

" Built-in functions
syn keyword prqlBuiltin  aggregate derive filter from group join select sort take window

" Built-in types
syn keyword prqlType     bool float int int8 int16 int32 int64 int128 text date time timestamp

" avoid highlighting attributes as builtins
syn match   prqlAttribute  /\.\h\w*/hs=s+1
  \ contains=ALLBUT,prqlBuiltin,prqlFunction
  \ transparent

if exists("prql_space_error_highlight")
  " trailing whitespace
  syn match   prqlSpaceError  display excludenl "\s\+$"
  " mixed tabs and spaces
  syn match   prqlSpaceError  display " \+\t"
  syn match   prqlSpaceError  display "\t\+ "
endif

" Do not spell doctests inside strings.
" Notice that the end of a string, either ''', or """, will end the contained
" doctest too.  Thus, we do *not* need to have it as an end pattern.
if !exists("prql_no_doctest_highlight")
  if !exists("prql_no_doctest_code_highlight")
    syn region prqlDoctest
    \ start="^\s*>>>\s" end="^\s*$"
    \ contained contains=ALLBUT,prqlDoctest,prqlFunction,@Spell
    syn region prqlDoctestValue
    \ start=+^\s*\%(>>>\s\|\.\.\.\s\|"""\|'''\)\@!\S\++ end="$"
    \ contained
  else
    syn region prqlDoctest
    \ start="^\s*>>>" end="^\s*$"
    \ contained contains=@NoSpell
  endif
endif

" The default highlight links.  Can be overridden later.
hi def link prqlBoolean         Boolean
hi def link prqlStatement       Statement
hi def link prqlType            Type
hi def link prqlConditional     Conditional
hi def link prqlRepeat          Repeat
hi def link prqlOperator        Operator
hi def link prqlInclude         Include
hi def link prqlAnnotation      Define
hi def link prqlAnnotationName  Function
hi def link prqlFunction        Function
hi def link prqlComment         Comment
hi def link prqlTodo            Todo
hi def link prqlSelf            Constant
hi def link prqlString          String
hi def link prqlFString         String
hi def link prqlRString         String
hi def link prqlSString         String
hi def link prqlQuotes          String
hi def link prqlTripleQuotes    prqlQuotes
hi def link prqlEscape          Special
if !exists("prql_no_number_highlight")
  hi def link prqlNumber    Number
endif
if !exists("prql_no_builtin_highlight")
  hi def link prqlBuiltin    Function
endif
if exists("prql_space_error_highlight")
  hi def link prqlSpaceError    Error
endif
if !exists("prql_no_doctest_highlight")
  hi def link prqlDoctest    Special
  hi def link prqlDoctestValue  Define
endif

let b:current_syntax = "prql"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:set sw=2 sts=2 ts=8 noet:
