" Vim syntax file
" Language: Monk (See-Beyond Technologies)
" Maintainer: Mike Litherland <litherm@ccf.org>
" Last Change: 2012 Feb 03 by Thilo Six

" This syntax file is good enough for my needs, but others
" may desire more features.  Suggestions and bug reports
" are solicited by the author (above).

" Originally based on the Scheme syntax file by:

" Maintainer:	Dirk van Deun <dvandeun@poboxes.com>
" Last Change:	April 30, 1998

" In fact it's almost identical. :)

" The original author's notes:
" This script incorrectly recognizes some junk input as numerals:
" parsing the complete system of Scheme numerals using the pattern
" language is practically impossible: I did a lax approximation.

" Initializing:

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case ignore

" Fascist highlighting: everything that doesn't fit the rules is an error...

syn match	monkError	oneline    ![^ \t()";]*!
syn match	monkError	oneline    ")"

" Quoted and backquoted stuff

syn region monkQuoted matchgroup=Delimiter start="['`]" end=![ \t()";]!me=e-1 contains=ALLBUT,monkStruc,monkSyntax,monkFunc

syn region monkQuoted matchgroup=Delimiter start="['`](" matchgroup=Delimiter end=")" contains=ALLBUT,monkStruc,monkSyntax,monkFunc
syn region monkQuoted matchgroup=Delimiter start="['`]#(" matchgroup=Delimiter end=")" contains=ALLBUT,monkStruc,monkSyntax,monkFunc

syn region monkStrucRestricted matchgroup=Delimiter start="(" matchgroup=Delimiter end=")" contains=ALLBUT,monkStruc,monkSyntax,monkFunc
syn region monkStrucRestricted matchgroup=Delimiter start="#(" matchgroup=Delimiter end=")" contains=ALLBUT,monkStruc,monkSyntax,monkFunc

syn region monkUnquote matchgroup=Delimiter start="," end=![ \t()";]!me=e-1 contains=ALLBUT,monkStruc,monkSyntax,monkFunc
syn region monkUnquote matchgroup=Delimiter start=",@" end=![ \t()";]!me=e-1 contains=ALLBUT,monkStruc,monkSyntax,monkFunc

syn region monkUnquote matchgroup=Delimiter start=",(" end=")" contains=ALLBUT,monkStruc,monkSyntax,monkFunc
syn region monkUnquote matchgroup=Delimiter start=",@(" end=")" contains=ALLBUT,monkStruc,monkSyntax,monkFunc

syn region monkUnquote matchgroup=Delimiter start=",#(" end=")" contains=ALLBUT,monkStruc,monkSyntax,monkFunc
syn region monkUnquote matchgroup=Delimiter start=",@#(" end=")" contains=ALLBUT,monkStruc,monkSyntax,monkFunc

" R5RS Scheme Functions and Syntax:

if version < 600
  set iskeyword=33,35-39,42-58,60-90,94,95,97-122,126,_
else
  setlocal iskeyword=33,35-39,42-58,60-90,94,95,97-122,126,_
endif

syn keyword monkSyntax lambda and or if cond case define let let* letrec
syn keyword monkSyntax begin do delay set! else =>
syn keyword monkSyntax quote quasiquote unquote unquote-splicing
syn keyword monkSyntax define-syntax let-syntax letrec-syntax syntax-rules

syn keyword monkFunc not boolean? eq? eqv? equal? pair? cons car cdr set-car!
syn keyword monkFunc set-cdr! caar cadr cdar cddr caaar caadr cadar caddr
syn keyword monkFunc cdaar cdadr cddar cdddr caaaar caaadr caadar caaddr
syn keyword monkFunc cadaar cadadr caddar cadddr cdaaar cdaadr cdadar cdaddr
syn keyword monkFunc cddaar cddadr cdddar cddddr null? list? list length
syn keyword monkFunc append reverse list-ref memq memv member assq assv assoc
syn keyword monkFunc symbol? symbol->string string->symbol number? complex?
syn keyword monkFunc real? rational? integer? exact? inexact? = < > <= >=
syn keyword monkFunc zero? positive? negative? odd? even? max min + * - / abs
syn keyword monkFunc quotient remainder modulo gcd lcm numerator denominator
syn keyword monkFunc floor ceiling truncate round rationalize exp log sin cos
syn keyword monkFunc tan asin acos atan sqrt expt make-rectangular make-polar
syn keyword monkFunc real-part imag-part magnitude angle exact->inexact
syn keyword monkFunc inexact->exact number->string string->number char=?
syn keyword monkFunc char-ci=? char<? char-ci<? char>? char-ci>? char<=?
syn keyword monkFunc char-ci<=? char>=? char-ci>=? char-alphabetic? char?
syn keyword monkFunc char-numeric? char-whitespace? char-upper-case?
syn keyword monkFunc char-lower-case?
syn keyword monkFunc char->integer integer->char char-upcase char-downcase
syn keyword monkFunc string? make-string string string-length string-ref
syn keyword monkFunc string-set! string=? string-ci=? string<? string-ci<?
syn keyword monkFunc string>? string-ci>? string<=? string-ci<=? string>=?
syn keyword monkFunc string-ci>=? substring string-append vector? make-vector
syn keyword monkFunc vector vector-length vector-ref vector-set! procedure?
syn keyword monkFunc apply map for-each call-with-current-continuation
syn keyword monkFunc call-with-input-file call-with-output-file input-port?
syn keyword monkFunc output-port? current-input-port current-output-port
syn keyword monkFunc open-input-file open-output-file close-input-port
syn keyword monkFunc close-output-port eof-object? read read-char peek-char
syn keyword monkFunc write display newline write-char call/cc
syn keyword monkFunc list-tail string->list list->string string-copy
syn keyword monkFunc string-fill! vector->list list->vector vector-fill!
syn keyword monkFunc force with-input-from-file with-output-to-file
syn keyword monkFunc char-ready? load transcript-on transcript-off eval
syn keyword monkFunc dynamic-wind port? values call-with-values
syn keyword monkFunc monk-report-environment null-environment
syn keyword monkFunc interaction-environment

" Keywords specific to STC's implementation

syn keyword monkFunc $event-clear $event-parse $event->string $make-event-map
syn keyword monkFunc $resolve-event-definition change-pattern copy copy-strip
syn keyword monkFunc count-data-children count-map-children count-rep data-map
syn keyword monkFunc duplicate duplicate-strip file-check file-lookup get
syn keyword monkFunc insert list-lookup node-has-data? not-verify path?
syn keyword monkFunc path-defined-as-repeating? path-nodeclear path-nodedepth
syn keyword monkFunc path-nodename path-nodeparentname path->string path-valid?
syn keyword monkFunc regex string->path timestamp uniqueid verify

" Keywords from the Monk function library (from e*Gate 4.1 programmers ref)
syn keyword monkFunc allcap? capitalize char-punctuation? char-substitute
syn keyword monkFunc char-to-char conv count-used-children degc->degf
syn keyword monkFunc diff-two-dates display-error empty-string? fail_id
syn keyword monkFunc fail_id_if fail_translation fail_translation_if
syn keyword monkFunc find-get-after find-get-before get-timestamp julian-date?
syn keyword monkFunc julian->standard leap-year? map-string not-empty-string?
syn keyword monkFunc standard-date? standard->julian string-begins-with?
syn keyword monkFunc string-contains? string-ends-with? string-search-from-left
syn keyword monkFunc string-search-from-right string->ssn strip-punct
syn keyword monkFunc strip-string substring=? symbol-table-get symbol-table-put
syn keyword monkFunc trim-string-left trim-string-right valid-decimal?
syn keyword monkFunc valid-integer? verify-type

" Writing out the complete description of Scheme numerals without
" using variables is a day's work for a trained secretary...
" This is a useful lax approximation:

syn match	monkNumber	oneline    "[-#+0-9.][-#+/0-9a-f@i.boxesfdl]*"
syn match	monkError	oneline    ![-#+0-9.][-#+/0-9a-f@i.boxesfdl]*[^-#+/0-9a-f@i.boxesfdl \t()";][^ \t()";]*!

syn match	monkOther	oneline    ![+-][ \t()";]!me=e-1
syn match	monkOther	oneline    ![+-]$!
" ... so that a single + or -, inside a quoted context, would not be
" interpreted as a number (outside such contexts, it's a monkFunc)

syn match	monkDelimiter	oneline    !\.[ \t()";]!me=e-1
syn match	monkDelimiter	oneline    !\.$!
" ... and a single dot is not a number but a delimiter

" Simple literals:

syn match	monkBoolean	oneline    "#[tf]"
syn match	monkError	oneline    !#[tf][^ \t()";]\+!

syn match	monkChar	oneline    "#\\"
syn match	monkChar	oneline    "#\\."
syn match	monkError	oneline    !#\\.[^ \t()";]\+!
syn match	monkChar	oneline    "#\\space"
syn match	monkError	oneline    !#\\space[^ \t()";]\+!
syn match	monkChar	oneline    "#\\newline"
syn match	monkError	oneline    !#\\newline[^ \t()";]\+!

" This keeps all other stuff unhighlighted, except *stuff* and <stuff>:

syn match	monkOther	oneline    ,[a-z!$%&*/:<=>?^_~][-a-z!$%&*/:<=>?^_~0-9+.@]*,
syn match	monkError	oneline    ,[a-z!$%&*/:<=>?^_~][-a-z!$%&*/:<=>?^_~0-9+.@]*[^-a-z!$%&*/:<=>?^_~0-9+.@ \t()";]\+[^ \t()";]*,

syn match	monkOther	oneline    "\.\.\."
syn match	monkError	oneline    !\.\.\.[^ \t()";]\+!
" ... a special identifier

syn match	monkConstant	oneline    ,\*[-a-z!$%&*/:<=>?^_~0-9+.@]*\*[ \t()";],me=e-1
syn match	monkConstant	oneline    ,\*[-a-z!$%&*/:<=>?^_~0-9+.@]*\*$,
syn match	monkError	oneline    ,\*[-a-z!$%&*/:<=>?^_~0-9+.@]*\*[^-a-z!$%&*/:<=>?^_~0-9+.@ \t()";]\+[^ \t()";]*,

syn match	monkConstant	oneline    ,<[-a-z!$%&*/:<=>?^_~0-9+.@]*>[ \t()";],me=e-1
syn match	monkConstant	oneline    ,<[-a-z!$%&*/:<=>?^_~0-9+.@]*>$,
syn match	monkError	oneline    ,<[-a-z!$%&*/:<=>?^_~0-9+.@]*>[^-a-z!$%&*/:<=>?^_~0-9+.@ \t()";]\+[^ \t()";]*,

" Monk input and output structures
syn match	monkSyntax	oneline    "\(\~input\|\[I\]->\)[^ \t]*"
syn match	monkFunc	oneline    "\(\~output\|\[O\]->\)[^ \t]*"

" Non-quoted lists, and strings:

syn region monkStruc matchgroup=Delimiter start="(" matchgroup=Delimiter end=")" contains=ALL
syn region monkStruc matchgroup=Delimiter start="#(" matchgroup=Delimiter end=")" contains=ALL

syn region	monkString	start=+"+  skip=+\\[\\"]+ end=+"+

" Comments:

syn match	monkComment	";.*$"

" Synchronization and the wrapping up...

syn sync match matchPlace grouphere NONE "^[^ \t]"
" ... i.e. synchronize on a line that starts at the left margin

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_monk_syntax_inits")
  if version < 508
    let did_monk_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink monkSyntax		Statement
  HiLink monkFunc		Function

  HiLink monkString		String
  HiLink monkChar		Character
  HiLink monkNumber		Number
  HiLink monkBoolean		Boolean

  HiLink monkDelimiter	Delimiter
  HiLink monkConstant	Constant

  HiLink monkComment		Comment
  HiLink monkError		Error

  delcommand HiLink
endif

let b:current_syntax = "monk"

let &cpo = s:cpo_save
unlet s:cpo_save
