" Vim syntax file
" Language:     LambdaProlog (Teyjus)
" Filenames:    *.mod *.sig
" Maintainer:   Markus Mottl  <markus.mottl@gmail.com>
" URL:          http://www.ocaml.info/vim/syntax/lprolog.vim
" Last Change:  2006 Feb 05
"               2001 Apr 26 - Upgraded for new Vim version
"               2000 Jun  5 - Initial release

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Lambda Prolog is case sensitive.
syn case match

syn match   lprologBrackErr    "\]"
syn match   lprologParenErr    ")"

syn cluster lprologContained contains=lprologTodo,lprologModuleName,lprologTypeNames,lprologTypeName

" Enclosing delimiters
syn region  lprologEncl transparent matchgroup=lprologKeyword start="(" matchgroup=lprologKeyword end=")" contains=ALLBUT,@lprologContained,lprologParenErr
syn region  lprologEncl transparent matchgroup=lprologKeyword start="\[" matchgroup=lprologKeyword end="\]" contains=ALLBUT,@lprologContained,lprologBrackErr

" General identifiers
syn match   lprologIdentifier  "\<\(\w\|[-+*/\\^<>=`'~?@#$&!_]\)*\>"
syn match   lprologVariable    "\<\(\u\|_\)\(\w\|[-+*/\\^<>=`'~?@#$&!]\)*\>"

syn match   lprologOperator  "/"

" Comments
syn region  lprologComment  start="/\*" end="\*/" contains=lprologComment,lprologTodo
syn region  lprologComment  start="%" end="$" contains=lprologTodo
syn keyword lprologTodo  contained TODO FIXME XXX

syn match   lprologInteger  "\<\d\+\>"
syn match   lprologReal     "\<\(\d\+\)\=\.\d+\>"
syn region  lprologString   start=+"+ skip=+\\\\\|\\"+ end=+"+

" Clause definitions
syn region  lprologClause start="^\w\+" end=":-\|\."

" Modules
syn region  lprologModule matchgroup=lprologKeyword start="^\<module\>" matchgroup=lprologKeyword end="\."

" Types
syn match   lprologKeyword "^\<type\>" skipwhite nextgroup=lprologTypeNames
syn region  lprologTypeNames matchgroup=lprologBraceErr start="\<\w\+\>" matchgroup=lprologKeyword end="\." contained contains=lprologTypeName,lprologOperator
syn match   lprologTypeName "\<\w\+\>" contained

" Keywords
syn keyword lprologKeyword  end import accumulate accum_sig
syn keyword lprologKeyword  local localkind closed sig
syn keyword lprologKeyword  kind exportdef useonly
syn keyword lprologKeyword  infixl infixr infix prefix
syn keyword lprologKeyword  prefixr postfix postfixl

syn keyword lprologSpecial  pi sigma is true fail halt stop not

" Operators
syn match   lprologSpecial ":-"
syn match   lprologSpecial "->"
syn match   lprologSpecial "=>"
syn match   lprologSpecial "\\"
syn match   lprologSpecial "!"

syn match   lprologSpecial ","
syn match   lprologSpecial ";"
syn match   lprologSpecial "&"

syn match   lprologOperator "+"
syn match   lprologOperator "-"
syn match   lprologOperator "*"
syn match   lprologOperator "\~"
syn match   lprologOperator "\^"
syn match   lprologOperator "<"
syn match   lprologOperator ">"
syn match   lprologOperator "=<"
syn match   lprologOperator ">="
syn match   lprologOperator "::"
syn match   lprologOperator "="

syn match   lprologOperator "\."
syn match   lprologOperator ":"
syn match   lprologOperator "|"

syn match   lprologCommentErr  "\*/"

syn sync minlines=50
syn sync maxlines=500


" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_lprolog_syntax_inits")
  if version < 508
    let did_lprolog_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink lprologComment     Comment
  HiLink lprologTodo	    Todo

  HiLink lprologKeyword     Keyword
  HiLink lprologSpecial     Special
  HiLink lprologOperator    Operator
  HiLink lprologIdentifier  Normal

  HiLink lprologInteger     Number
  HiLink lprologReal	    Number
  HiLink lprologString	    String

  HiLink lprologCommentErr  Error
  HiLink lprologBrackErr    Error
  HiLink lprologParenErr    Error

  HiLink lprologModuleName  Special
  HiLink lprologTypeName    Identifier

  HiLink lprologVariable    Keyword
  HiLink lprologAtom	    Normal
  HiLink lprologClause	    Type

  delcommand HiLink
endif

let b:current_syntax = "lprolog"

" vim: ts=8
