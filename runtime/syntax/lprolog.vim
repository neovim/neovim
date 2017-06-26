" Vim syntax file
" Language:     LambdaProlog (Teyjus)
" Filenames:    *.mod *.sig
" Maintainer:   Markus Mottl  <markus.mottl@gmail.com>
" URL:          http://www.ocaml.info/vim/syntax/lprolog.vim
" Last Change:  2006 Feb 05
"               2001 Apr 26 - Upgraded for new Vim version
"               2000 Jun  5 - Initial release

" quit when a syntax file was already loaded
if exists("b:current_syntax")
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
" Only when an item doesn't have highlighting yet

hi def link lprologComment     Comment
hi def link lprologTodo	    Todo

hi def link lprologKeyword     Keyword
hi def link lprologSpecial     Special
hi def link lprologOperator    Operator
hi def link lprologIdentifier  Normal

hi def link lprologInteger     Number
hi def link lprologReal	    Number
hi def link lprologString	    String

hi def link lprologCommentErr  Error
hi def link lprologBrackErr    Error
hi def link lprologParenErr    Error

hi def link lprologModuleName  Special
hi def link lprologTypeName    Identifier

hi def link lprologVariable    Keyword
hi def link lprologAtom	    Normal
hi def link lprologClause	    Type


let b:current_syntax = "lprolog"

" vim: ts=8
