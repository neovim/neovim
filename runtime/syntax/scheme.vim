" Vim syntax file
" Language: Scheme (R7RS)
" Last Change: 2021-01-03
" Author: Evan Hanson <evhan@foldling.org>
" Maintainer: Evan Hanson <evhan@foldling.org>
" Previous Author: Dirk van Deun <dirk@igwe.vub.ac.be>
" Previous Maintainer: Sergey Khorev <sergey.khorev@gmail.com>
" Repository: https://git.foldling.org/vim-scheme.git
" URL: https://foldling.org/vim/syntax/scheme.vim

if exists('b:current_syntax')
  finish
endif

let s:cpo = &cpo
set cpo&vim

syn spell notoplevel

syn match schemeParentheses "[^ '`\t\n()\[\]";]\+"
syn match schemeParentheses "[)\]]"

syn match schemeIdentifier /[^ '`\t\n()\[\]"|;][^ '`\t\n()\[\]"|;]*/

syn region schemeQuote matchgroup=schemeData start=/'[`']*/ end=/[ \t\n()\[\]";]/me=e-1
syn region schemeQuote matchgroup=schemeData start=/'['`]*"/ skip=/\\[\\"]/ end=/"/
syn region schemeQuote matchgroup=schemeData start=/'['`]*|/ skip=/\\[\\|]/ end=/|/
syn region schemeQuote matchgroup=schemeData start=/'['`]*#\?(/ end=/)/ contains=ALLBUT,schemeQuasiquote,schemeQuasiquoteForm,schemeUnquote,schemeForm,schemeDatumCommentForm,schemeImport,@schemeImportCluster,@schemeSyntaxCluster

syn region schemeQuasiquote matchgroup=schemeData start=/`['`]*/ end=/[ \t\n()\[\]";]/me=e-1
syn region schemeQuasiquote matchgroup=schemeData start=/`['`]*#\?(/ end=/)/ contains=ALLBUT,schemeQuote,schemeQuoteForm,schemeForm,schemeDatumCommentForm,schemeImport,@schemeImportCluster,@schemeSyntaxCluster

syn region schemeUnquote matchgroup=schemeParentheses start=/,/ end=/[ `'\t\n\[\]()";]/me=e-1 contained contains=ALLBUT,schemeDatumCommentForm,@schemeImportCluster
syn region schemeUnquote matchgroup=schemeParentheses start=/,@/ end=/[ `'\t\n\[\]()";]/me=e-1 contained contains=ALLBUT,schemeDatumCommentForm,@schemeImportCluster
syn region schemeUnquote matchgroup=schemeParentheses start=/,(/ end=/)/ contained contains=ALLBUT,schemeDatumCommentForm,@schemeImportCluster
syn region schemeUnquote matchgroup=schemeParentheses start=/,@(/ end=/)/ contained contains=ALLBUT,schemeDatumCommentForm,@schemeImportCluster

syn region schemeQuoteForm matchgroup=schemeData start=/(/ end=/)/ contained contains=ALLBUT,schemeQuasiquote,schemeQuasiquoteForm,schemeUnquote,schemeForm,schemeDatumCommentForm,schemeImport,@schemeImportCluster,@schemeSyntaxCluster
syn region schemeQuasiquoteForm matchgroup=schemeData start=/(/ end=/)/ contained contains=ALLBUT,schemeQuote,schemeForm,schemeDatumCommentForm,schemeImport,@schemeImportCluster,@schemeSyntaxCluster

syn region schemeString start=/\(\\\)\@<!"/ skip=/\\[\\"]/ end=/"/ contains=@Spell
syn region schemeSymbol start=/\(\\\)\@<!|/ skip=/\\[\\|]/ end=/|/

syn match schemeNumber /\(#[dbeio]\)*[+\-]*\([0-9]\+\|inf.0\|nan.0\)\(\/\|\.\)\?[0-9+\-@\ilns]*\>/
syn match schemeNumber /#x[+\-]*[0-9a-fA-F]\+\>/

syn match schemeBoolean /#t\(rue\)\?/
syn match schemeBoolean /#f\(alse\)\?/

syn match schemeCharacter /#\\.[^ `'\t\n\[\]()]*/
syn match schemeCharacter /#\\x[0-9a-fA-F]\+/

syn match schemeComment /;.*$/ contains=@Spell

syn region schemeMultilineComment start=/#|/ end=/|#/ contains=schemeMultilineComment,@Spell

syn region schemeForm matchgroup=schemeParentheses start="(" end=")" contains=ALLBUT,schemeUnquote,schemeDatumCommentForm,@schemeImportCluster
syn region schemeForm matchgroup=schemeParentheses start="\[" end="\]" contains=ALLBUT,schemeUnquote,schemeDatumCommentForm,@schemeImportCluster

syn region schemeVector matchgroup=schemeData start="#(" end=")" contains=ALLBUT,schemeQuasiquote,schemeQuasiquoteForm,schemeUnquote,schemeForm,schemeDatumCommentForm,schemeImport,@schemeImportCluster,@schemeSyntaxCluster
syn region schemeVector matchgroup=schemeData start="#[fsu]\d\+(" end=")" contains=schemeNumber,schemeComment,schemeDatumComment

if exists('g:is_chicken') || exists('b:is_chicken')
  syn region schemeImport matchgroup=schemeImport start="\(([ \t\n]*\)\@<=\(import\|import-syntax\|use\|require-extension\)\(-for-syntax\)\?\>" end=")"me=e-1 contained contains=schemeImportForm,schemeIdentifier,schemeComment,schemeDatumComment
else
  syn region schemeImport matchgroup=schemeImport start="\(([ \t\n]*\)\@<=\(import\)\>" end=")"me=e-1 contained contains=schemeImportForm,schemeIdentifier,schemeComment,schemeDatumComment
endif

syn match   schemeImportKeyword "\(([ \t\n]*\)\@<=\(except\|only\|prefix\|rename\)\>"
syn region  schemeImportForm matchgroup=schemeParentheses start="(" end=")" contained contains=schemeIdentifier,schemeComment,schemeDatumComment,@schemeImportCluster
syn cluster schemeImportCluster contains=schemeImportForm,schemeImportKeyword

syn region schemeDatumComment matchgroup=schemeDatumComment start=/#;[ \t\n`']*/ end=/[ \t\n()\[\]";]/me=e-1
syn region schemeDatumComment matchgroup=schemeDatumComment start=/#;[ \t\n`']*"/ skip=/\\[\\"]/ end=/"/
syn region schemeDatumComment matchgroup=schemeDatumComment start=/#;[ \t\n`']*|/ skip=/\\[\\|]/ end=/|/
syn region schemeDatumComment matchgroup=schemeDatumComment start=/#;[ \t\n`']*\(#\([usf]\d\+\)\?\)\?(/ end=/)/ contains=schemeDatumCommentForm
syn region schemeDatumCommentForm start="(" end=")" contained contains=schemeDatumCommentForm

syn cluster schemeSyntaxCluster contains=schemeFunction,schemeKeyword,schemeSyntax,schemeExtraSyntax,schemeLibrarySyntax,schemeSyntaxSyntax

syn keyword schemeLibrarySyntax define-library
syn keyword schemeLibrarySyntax export
syn keyword schemeLibrarySyntax include
syn keyword schemeLibrarySyntax include-ci
syn keyword schemeLibrarySyntax include-library-declarations
syn keyword schemeLibrarySyntax library
syn keyword schemeLibrarySyntax cond-expand

syn keyword schemeSyntaxSyntax define-syntax
syn keyword schemeSyntaxSyntax let-syntax
syn keyword schemeSyntaxSyntax letrec-syntax
syn keyword schemeSyntaxSyntax syntax-rules

syn keyword schemeSyntax =>
syn keyword schemeSyntax and
syn keyword schemeSyntax begin
syn keyword schemeSyntax case
syn keyword schemeSyntax case-lambda
syn keyword schemeSyntax cond
syn keyword schemeSyntax define
syn keyword schemeSyntax define-record-type
syn keyword schemeSyntax define-values
syn keyword schemeSyntax delay
syn keyword schemeSyntax delay-force
syn keyword schemeSyntax do
syn keyword schemeSyntax else
syn keyword schemeSyntax guard
syn keyword schemeSyntax if
syn keyword schemeSyntax lambda
syn keyword schemeSyntax let
syn keyword schemeSyntax let*
syn keyword schemeSyntax let*-values
syn keyword schemeSyntax let-values
syn keyword schemeSyntax letrec
syn keyword schemeSyntax letrec*
syn keyword schemeSyntax or
syn keyword schemeSyntax parameterize
syn keyword schemeSyntax quasiquote
syn keyword schemeSyntax quote
syn keyword schemeSyntax set!
syn keyword schemeSyntax unless
syn keyword schemeSyntax unquote
syn keyword schemeSyntax unquote-splicing
syn keyword schemeSyntax when

syn keyword schemeFunction *
syn keyword schemeFunction +
syn keyword schemeFunction -
syn keyword schemeFunction /
syn keyword schemeFunction <
syn keyword schemeFunction <=
syn keyword schemeFunction =
syn keyword schemeFunction >
syn keyword schemeFunction >=
syn keyword schemeFunction abs
syn keyword schemeFunction acos
syn keyword schemeFunction acos
syn keyword schemeFunction angle
syn keyword schemeFunction append
syn keyword schemeFunction apply
syn keyword schemeFunction asin
syn keyword schemeFunction assoc
syn keyword schemeFunction assq
syn keyword schemeFunction assv
syn keyword schemeFunction atan
syn keyword schemeFunction binary-port?
syn keyword schemeFunction boolean=?
syn keyword schemeFunction boolean?
syn keyword schemeFunction bytevector
syn keyword schemeFunction bytevector-append
syn keyword schemeFunction bytevector-append
syn keyword schemeFunction bytevector-copy
syn keyword schemeFunction bytevector-copy!
syn keyword schemeFunction bytevector-length
syn keyword schemeFunction bytevector-u8-ref
syn keyword schemeFunction bytevector-u8-set!
syn keyword schemeFunction bytevector?
syn keyword schemeFunction caaaar
syn keyword schemeFunction caaadr
syn keyword schemeFunction caaar
syn keyword schemeFunction caadar
syn keyword schemeFunction caaddr
syn keyword schemeFunction caadr
syn keyword schemeFunction caar
syn keyword schemeFunction cadaar
syn keyword schemeFunction cadadr
syn keyword schemeFunction cadar
syn keyword schemeFunction caddar
syn keyword schemeFunction cadddr
syn keyword schemeFunction caddr
syn keyword schemeFunction cadr
syn keyword schemeFunction call-with-current-continuation
syn keyword schemeFunction call-with-input-file
syn keyword schemeFunction call-with-output-file
syn keyword schemeFunction call-with-port
syn keyword schemeFunction call-with-values
syn keyword schemeFunction call/cc
syn keyword schemeFunction car
syn keyword schemeFunction cdaaar
syn keyword schemeFunction cdaadr
syn keyword schemeFunction cdaar
syn keyword schemeFunction cdadar
syn keyword schemeFunction cdaddr
syn keyword schemeFunction cdadr
syn keyword schemeFunction cdar
syn keyword schemeFunction cddaar
syn keyword schemeFunction cddadr
syn keyword schemeFunction cddar
syn keyword schemeFunction cdddar
syn keyword schemeFunction cddddr
syn keyword schemeFunction cdddr
syn keyword schemeFunction cddr
syn keyword schemeFunction cdr
syn keyword schemeFunction ceiling
syn keyword schemeFunction char->integer
syn keyword schemeFunction char-alphabetic?
syn keyword schemeFunction char-ci<=?
syn keyword schemeFunction char-ci<?
syn keyword schemeFunction char-ci=?
syn keyword schemeFunction char-ci>=?
syn keyword schemeFunction char-ci>?
syn keyword schemeFunction char-downcase
syn keyword schemeFunction char-foldcase
syn keyword schemeFunction char-lower-case?
syn keyword schemeFunction char-numeric?
syn keyword schemeFunction char-ready?
syn keyword schemeFunction char-upcase
syn keyword schemeFunction char-upper-case?
syn keyword schemeFunction char-whitespace?
syn keyword schemeFunction char<=?
syn keyword schemeFunction char<?
syn keyword schemeFunction char=?
syn keyword schemeFunction char>=?
syn keyword schemeFunction char>?
syn keyword schemeFunction char?
syn keyword schemeFunction close-input-port
syn keyword schemeFunction close-output-port
syn keyword schemeFunction close-port
syn keyword schemeFunction command-line
syn keyword schemeFunction complex?
syn keyword schemeFunction cons
syn keyword schemeFunction cos
syn keyword schemeFunction current-error-port
syn keyword schemeFunction current-input-port
syn keyword schemeFunction current-jiffy
syn keyword schemeFunction current-output-port
syn keyword schemeFunction current-second
syn keyword schemeFunction delete-file
syn keyword schemeFunction denominator
syn keyword schemeFunction digit-value
syn keyword schemeFunction display
syn keyword schemeFunction dynamic-wind
syn keyword schemeFunction emergency-exit
syn keyword schemeFunction environment
syn keyword schemeFunction eof-object
syn keyword schemeFunction eof-object?
syn keyword schemeFunction eq?
syn keyword schemeFunction equal?
syn keyword schemeFunction eqv?
syn keyword schemeFunction error
syn keyword schemeFunction error-object-irritants
syn keyword schemeFunction error-object-message
syn keyword schemeFunction error-object?
syn keyword schemeFunction eval
syn keyword schemeFunction even?
syn keyword schemeFunction exact
syn keyword schemeFunction exact->inexact
syn keyword schemeFunction exact-integer-sqrt
syn keyword schemeFunction exact-integer?
syn keyword schemeFunction exact?
syn keyword schemeFunction exit
syn keyword schemeFunction exp
syn keyword schemeFunction expt
syn keyword schemeFunction features
syn keyword schemeFunction file-error?
syn keyword schemeFunction file-exists?
syn keyword schemeFunction finite?
syn keyword schemeFunction floor
syn keyword schemeFunction floor-quotient
syn keyword schemeFunction floor-remainder
syn keyword schemeFunction floor/
syn keyword schemeFunction flush-output-port
syn keyword schemeFunction for-each
syn keyword schemeFunction force
syn keyword schemeFunction gcd
syn keyword schemeFunction get-environment-variable
syn keyword schemeFunction get-environment-variables
syn keyword schemeFunction get-output-bytevector
syn keyword schemeFunction get-output-string
syn keyword schemeFunction imag-part
syn keyword schemeFunction inexact
syn keyword schemeFunction inexact->exact
syn keyword schemeFunction inexact?
syn keyword schemeFunction infinite?
syn keyword schemeFunction input-port-open?
syn keyword schemeFunction input-port?
syn keyword schemeFunction integer->char
syn keyword schemeFunction integer?
syn keyword schemeFunction interaction-environment
syn keyword schemeFunction jiffies-per-second
syn keyword schemeFunction lcm
syn keyword schemeFunction length
syn keyword schemeFunction list
syn keyword schemeFunction list->string
syn keyword schemeFunction list->vector
syn keyword schemeFunction list-copy
syn keyword schemeFunction list-ref
syn keyword schemeFunction list-set!
syn keyword schemeFunction list-tail
syn keyword schemeFunction list?
syn keyword schemeFunction load
syn keyword schemeFunction log
syn keyword schemeFunction magnitude
syn keyword schemeFunction make-bytevector
syn keyword schemeFunction make-list
syn keyword schemeFunction make-parameter
syn keyword schemeFunction make-polar
syn keyword schemeFunction make-promise
syn keyword schemeFunction make-rectangular
syn keyword schemeFunction make-string
syn keyword schemeFunction make-vector
syn keyword schemeFunction map
syn keyword schemeFunction max
syn keyword schemeFunction member
syn keyword schemeFunction memq
syn keyword schemeFunction memv
syn keyword schemeFunction min
syn keyword schemeFunction modulo
syn keyword schemeFunction nan?
syn keyword schemeFunction negative?
syn keyword schemeFunction newline
syn keyword schemeFunction not
syn keyword schemeFunction null-environment
syn keyword schemeFunction null?
syn keyword schemeFunction number->string
syn keyword schemeFunction number?
syn keyword schemeFunction numerator
syn keyword schemeFunction odd?
syn keyword schemeFunction open-binary-input-file
syn keyword schemeFunction open-binary-output-file
syn keyword schemeFunction open-input-bytevector
syn keyword schemeFunction open-input-file
syn keyword schemeFunction open-input-string
syn keyword schemeFunction open-output-bytevector
syn keyword schemeFunction open-output-file
syn keyword schemeFunction open-output-string
syn keyword schemeFunction output-port-open?
syn keyword schemeFunction output-port?
syn keyword schemeFunction pair?
syn keyword schemeFunction peek-char
syn keyword schemeFunction peek-u8
syn keyword schemeFunction port?
syn keyword schemeFunction positive?
syn keyword schemeFunction procedure?
syn keyword schemeFunction promise?
syn keyword schemeFunction quotient
syn keyword schemeFunction raise
syn keyword schemeFunction raise-continuable
syn keyword schemeFunction rational?
syn keyword schemeFunction rationalize
syn keyword schemeFunction read
syn keyword schemeFunction read-bytevector
syn keyword schemeFunction read-bytevector!
syn keyword schemeFunction read-char
syn keyword schemeFunction read-error?
syn keyword schemeFunction read-line
syn keyword schemeFunction read-string
syn keyword schemeFunction read-u8
syn keyword schemeFunction real-part
syn keyword schemeFunction real?
syn keyword schemeFunction remainder
syn keyword schemeFunction reverse
syn keyword schemeFunction round
syn keyword schemeFunction scheme-report-environment
syn keyword schemeFunction set-car!
syn keyword schemeFunction set-cdr!
syn keyword schemeFunction sin
syn keyword schemeFunction sqrt
syn keyword schemeFunction square
syn keyword schemeFunction string
syn keyword schemeFunction string->list
syn keyword schemeFunction string->number
syn keyword schemeFunction string->symbol
syn keyword schemeFunction string->utf8
syn keyword schemeFunction string->vector
syn keyword schemeFunction string-append
syn keyword schemeFunction string-ci<=?
syn keyword schemeFunction string-ci<?
syn keyword schemeFunction string-ci=?
syn keyword schemeFunction string-ci>=?
syn keyword schemeFunction string-ci>?
syn keyword schemeFunction string-copy
syn keyword schemeFunction string-copy!
syn keyword schemeFunction string-downcase
syn keyword schemeFunction string-fill!
syn keyword schemeFunction string-foldcase
syn keyword schemeFunction string-for-each
syn keyword schemeFunction string-length
syn keyword schemeFunction string-map
syn keyword schemeFunction string-ref
syn keyword schemeFunction string-set!
syn keyword schemeFunction string-upcase
syn keyword schemeFunction string<=?
syn keyword schemeFunction string<?
syn keyword schemeFunction string=?
syn keyword schemeFunction string>=?
syn keyword schemeFunction string>?
syn keyword schemeFunction string?
syn keyword schemeFunction substring
syn keyword schemeFunction symbol->string
syn keyword schemeFunction symbol=?
syn keyword schemeFunction symbol?
syn keyword schemeFunction syntax-error
syn keyword schemeFunction tan
syn keyword schemeFunction textual-port?
syn keyword schemeFunction transcript-off
syn keyword schemeFunction transcript-on
syn keyword schemeFunction truncate
syn keyword schemeFunction truncate-quotient
syn keyword schemeFunction truncate-remainder
syn keyword schemeFunction truncate/
syn keyword schemeFunction u8-ready?
syn keyword schemeFunction utf8->string
syn keyword schemeFunction values
syn keyword schemeFunction vector
syn keyword schemeFunction vector->list
syn keyword schemeFunction vector->string
syn keyword schemeFunction vector-append
syn keyword schemeFunction vector-copy
syn keyword schemeFunction vector-copy!
syn keyword schemeFunction vector-fill!
syn keyword schemeFunction vector-for-each
syn keyword schemeFunction vector-length
syn keyword schemeFunction vector-map
syn keyword schemeFunction vector-ref
syn keyword schemeFunction vector-set!
syn keyword schemeFunction vector?
syn keyword schemeFunction with-exception-handler
syn keyword schemeFunction with-input-from-file
syn keyword schemeFunction with-output-to-file
syn keyword schemeFunction write
syn keyword schemeFunction write-bytevector
syn keyword schemeFunction write-char
syn keyword schemeFunction write-shared
syn keyword schemeFunction write-simple
syn keyword schemeFunction write-string
syn keyword schemeFunction write-u8
syn keyword schemeFunction zero?

hi def link schemeBoolean Boolean
hi def link schemeCharacter Character
hi def link schemeComment Comment
hi def link schemeConstant Constant
hi def link schemeData Delimiter
hi def link schemeDatumComment Comment
hi def link schemeDatumCommentForm Comment
hi def link schemeDelimiter Delimiter
hi def link schemeError Error
hi def link schemeExtraSyntax Underlined
hi def link schemeFunction Function
hi def link schemeIdentifier Normal
hi def link schemeImport PreProc
hi def link schemeImportKeyword PreProc
hi def link schemeKeyword Type
hi def link schemeLibrarySyntax PreProc
hi def link schemeMultilineComment Comment
hi def link schemeNumber Number
hi def link schemeParentheses Normal
hi def link schemeQuasiquote Delimiter
hi def link schemeQuote Delimiter
hi def link schemeSpecialSyntax Special
hi def link schemeString String
hi def link schemeSymbol Normal
hi def link schemeSyntax Statement
hi def link schemeSyntaxSyntax PreProc
hi def link schemeTypeSyntax Type

let b:did_scheme_syntax = 1

if exists('b:is_chicken') || exists('g:is_chicken')
  exe 'ru! syntax/chicken.vim'
endif

unlet b:did_scheme_syntax
let b:current_syntax = 'scheme'
let &cpo = s:cpo
unlet s:cpo
