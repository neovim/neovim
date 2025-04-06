" Vim syntax file
" Language:             Racket
" Maintainer:           D. Ben Knoble <ben.knoble+github@gmail.com>
" Previous Maintainer:  Will Langstroth <will@langstroth.com>
" URL:                  https://github.com/benknoble/vim-racket
" Description:          Contains all of the keywords in #lang racket
" Last Change:          2024 Apr 14

" Initializing:
if exists("b:current_syntax")
  finish
endif

" Highlight unmatched parens
syntax match racketError ,[]})],

if version < 800
  set iskeyword=33,35-39,42-58,60-90,94,95,97-122,126,_
else
  " syntax iskeyword 33,35-39,42-58,60-90,94,95,97-122,126,_
  " converted from decimal to char
  " :s/\d\+/\=submatch(0)->str2nr()->nr2char()/g
  " but corrected to remove duplicate _, move ^ to end
  syntax iskeyword @,!,#-',*-:,<-Z,a-z,~,_,^
  " expanded
  " syntax iskeyword !,#,$,%,&,',*,+,,,-,.,/,0-9,:,<,=,>,?,@,A-Z,_,a-z,~,^
endif

" Forms in order of appearance at
" http://docs.racket-lang.org/reference/index.html
"
syntax keyword racketSyntax module module* module+ require provide quote
syntax keyword racketSyntax #%module-begin #%datum #%expression #%top #%variable-reference #%app
syntax keyword racketSyntax lambda case-lambda let let* letrec
syntax keyword racketSyntax let-values let*-values let-syntax letrec-syntax
syntax keyword racketSyntax let-syntaxes letrec-syntaxes letrec-syntaxes+values
syntax keyword racketSyntax local shared
syntax keyword racketSyntax if cond and or case define else =>
syntax keyword racketSyntax define define-values define-syntax define-syntaxes
syntax keyword racketSyntax define-for-syntax define-require-syntax define-provide-syntax
syntax keyword racketSyntax define-syntax-rule
syntax keyword racketSyntax define-record-type
syntax keyword racketSyntax begin begin0
syntax keyword racketSyntax begin-for-syntax
syntax keyword racketSyntax when unless
syntax keyword racketSyntax set! set!-values
syntax keyword racketSyntax for for/list for/vector for/hash for/hasheq for/hasheqv
syntax keyword racketSyntax for/and for/or for/lists for/first
syntax keyword racketSyntax for/last for/fold
syntax keyword racketSyntax for* for*/list for*/vector for*/hash for*/hasheq for*/hasheqv
syntax keyword racketSyntax for*/and for*/or for*/lists for*/first
syntax keyword racketSyntax for*/last for*/fold
syntax keyword racketSyntax for/fold/derived for*/fold/derived
syntax keyword racketSyntax define-sequence-syntax :do-in do
syntax keyword racketSyntax with-continuation-mark
syntax keyword racketSyntax quasiquote unquote unquote-splicing quote-syntax
syntax keyword racketSyntax #%top-interaction
syntax keyword racketSyntax define-package open-package package-begin
syntax keyword racketSyntax define* define*-values define*-syntax define*-syntaxes open*-package
syntax keyword racketSyntax package? package-exported-identifiers package-original-identifiers
syntax keyword racketSyntax block #%stratified-body

" 8 Contracts
" 8.2 Function contracts
syntax keyword racketSyntax -> ->* ->i ->d case-> dynamic->* unconstrained-domain->

" 8.6.1 Nested Contract Boundaries
syntax keyword racketSyntax with-contract define/contract define-struct/contract
syntax keyword racketSyntax invariant-assertion current-contract-region

" 9 Pattern Matching
syntax keyword racketSyntax match match* match/values define/match
syntax keyword racketSyntax match-lambda match-lambda* match-lambda**
syntax keyword racketSyntax match-let match-let* match-let-values match-let*-values
syntax keyword racketSyntax match-letrec match-define match-define-values

" 10.2.3 Handling Exceptions
syntax keyword racketSyntax with-handlers with-handlers*

" 10.4 Continuations
syntax keyword racketSyntax let/cc let/ec

" 10.4.1 Additional Control Operators
syntax keyword racketSyntax % prompt control prompt-at control-at reset shift
syntax keyword racketSyntax reset-at shift-at prompt0 reset0 control0 shift0
syntax keyword racketSyntax prompt0-at reset0-at control0-at shift0-at
syntax keyword racketSyntax set cupto

" 11.3.2 Parameters
syntax keyword racketSyntax parameterize parameterize*

" 12.5 Writing
syntax keyword racketSyntax write display displayln print
syntax keyword racketSyntax fprintf printf eprintf format
syntax keyword racketSyntax print-pair-curly-braces print-mpair-curly-braces print-unreadable
syntax keyword racketSyntax print-graph print-struct print-box print-vector-length print-hash-table
syntax keyword racketSyntax print-boolean-long-form print-reader-abbreviations print-as-expression print-syntax-width
syntax keyword racketSyntax current-write-relative-directory port-write-handler port-display-handler
syntax keyword racketSyntax port-print-handler global-port-print-handler

" 13.7 Custodians
syntax keyword racketSyntax custodian? custodian-memory-accounting-available? custodian-box?
syntax keyword racketSyntax make-custodian custodian-shutdown-all current-custodian custodian-managed-list
syntax keyword racketSyntax custodian-require-memory custodian-limit-memory
syntax keyword racketSyntax make-custodian-box custodian-box-value

" lambda sign
syntax match racketSyntax /\<[\u03bb]\>/


" Functions ==================================================================

syntax keyword racketFunc boolean? not equal? eqv? eq? equal?/recur immutable?
syntax keyword racketFunc true false symbol=? boolean=? false?
syntax keyword racketFunc number? complex? real? rational? integer?
syntax keyword racketFunc exact-integer? exact-nonnegative-integer?
syntax keyword racketFunc exact-positive-integer? inexact-real?
syntax keyword racketFunc fixnum? flonum? zero? positive? negative?
syntax keyword racketFunc even? odd? exact? inexact?
syntax keyword racketFunc inexact->exact exact->inexact

" 3.2.2 General Arithmetic

" 3.2.2.1 Arithmetic
syntax keyword racketFunc + - * / quotient remainder quotient/remainder modulo
syntax keyword racketFunc add1 sub1 abs max min gcd lcm round exact-round floor
syntax keyword racketFunc ceiling truncate numerator denominator rationalize

" 3.2.2.2 Number Comparison
syntax keyword racketFunc = < <= > >=

" 3.2.2.3 Powers and Roots
syntax keyword racketFunc sqrt integer-sqrt integer-sqrt/remainder
syntax keyword racketFunc expt exp log

" 3.2.2.3 Trigonometric Functions
syntax keyword racketFunc sin cos tan asin acos atan

" 3.2.2.4 Complex Numbers
syntax keyword racketFunc make-rectangular make-polar
syntax keyword racketFunc real-part imag-part magnitude angle
syntax keyword racketFunc bitwise-ior bitwise-and bitwise-xor bitwise-not
syntax keyword racketFunc bitwise-bit-set? bitwise-bit-field arithmetic-shift
syntax keyword racketFunc integer-length

" 3.2.2.5 Random Numbers
syntax keyword racketFunc random random-seed
syntax keyword racketFunc make-pseudo-random-generator pseudo-random-generator?
syntax keyword racketFunc current-pseudo-random-generator pseudo-random-generator->vector
syntax keyword racketFunc vector->pseudo-random-generator vector->pseudo-random-generator!

" 3.2.2.8 Number-String Conversions
syntax keyword racketFunc number->string string->number real->decimal-string
syntax keyword racketFunc integer->integer-bytes
syntax keyword racketFunc floating-point-bytes->real real->floating-point-bytes
syntax keyword racketFunc system-big-endian?

" 3.2.2.9 Extra Constants and Functions
syntax keyword racketFunc pi sqr sgn conjugate sinh cosh tanh order-of-magnitude

" 3.2.3 Flonums

" 3.2.3.1 Flonum Arithmetic
syntax keyword racketFunc fl+ fl- fl* fl/ flabs
syntax keyword racketFunc fl= fl< fl> fl<= fl>= flmin flmax
syntax keyword racketFunc flround flfloor flceiling fltruncate
syntax keyword racketFunc flsin flcos fltan flasin flacos flatan
syntax keyword racketFunc fllog flexp flsqrt
syntax keyword racketFunc ->fl fl->exact-integer make-flrectangular
syntax keyword racketFunc flreal-part flimag-part

" 3.2.3.2 Flonum Vectors
syntax keyword racketFunc flvector? flvector make-flvector flvector-length
syntax keyword racketFunc flvector-ref flvector-set! flvector-copy in-flvector
syntax keyword racketFunc shared-flvector make-shared-flvector
syntax keyword racketSyntax for/flvector for*/flvector

" 3.2.4 Fixnums
syntax keyword racketFunc fx+ fx- fx* fxquotient fxremainder fxmodulo fxabs
syntax keyword racketFunc fxand fxior fxxor fxnot fxlshift fxrshift
syntax keyword racketFunc fx= fx< fx> fx<= fx>= fxmin fxmax fx->fl fl->fx

" 3.2.4.2 Fixnum Vectors
syntax keyword racketFunc fxvector? fxvector make-fxvector fxvector-length
syntax keyword racketFunc fxvector-ref fxvector-set! fxvector-copy in-fxvector
syntax keyword racketFunc for/fxvector for*/fxvector
syntax keyword racketFunc shared-fxvector make-shared-fxvector

" 3.3 Strings
syntax keyword racketFunc string? make-string string string->immutable-string string-length
syntax keyword racketFunc string-ref string-set! substring string-copy string-copy!
syntax keyword racketFunc string-fill! string-append string->list list->string
syntax keyword racketFunc build-string string=? string<? string<=? string>? string>=?
syntax keyword racketFunc string-ci=? string-ci<? string-ci<=? string-ci>? string-ci>=?
syntax keyword racketFunc string-upcase string-downcase string-titlecase string-foldcase
syntax keyword racketFunc string-normalize-nfd string-normalize-nfc string-normalize-nfkc
syntax keyword racketFunc string-normalize-spaces string-trim
syntax keyword racketFunc string-locale=? string-locale>? string-locale<?
syntax keyword racketFunc string-locale-ci=? string-locale<=?
syntax keyword racketFunc string-locale-upcase string-locale-downcase
syntax keyword racketFunc string-append* string-join

" 3.4 Bytestrings
syntax keyword racketFunc bytes? make-bytes bytes bytes->immutable-bytes byte?
syntax keyword racketFunc bytes-length bytes-ref bytes-set! subbytes bytes-copy
syntax keyword racketFunc bytes-copy! bytes-fill! bytes-append bytes->list list->bytes
syntax keyword racketFunc make-shared-bytes shared-bytes
syntax keyword racketFunc bytes=? bytes<? bytes>?
syntax keyword racketFunc bytes->string/utf-8 bytes->string/latin-1
syntax keyword racketFunc string->bytes/locale string->bytes/latin-1 string->bytes/utf-8
syntax keyword racketFunc string-utf-8-length bytes-utf8-ref bytes-utf-8-index
syntax keyword racketFunc bytes-open-converter bytes-close-converter
syntax keyword racketFunc bytes-convert bytes-convert-end bytes-converter?
syntax keyword racketFunc locale-string-encoding

" 3.5 Characters
syntax keyword racketFunc char? char->integer integer->char
syntax keyword racketFunc char=? char<? char<=? char>? char>=?
syntax keyword racketFunc char-ci=? char-ci<? char-ci<=? char-ci>? char-ci>=?
syntax keyword racketFunc char-alphabetic? char-lower-case? char-upper-case? char-title-case?
syntax keyword racketFunc char-numeric? char-symbolic? char-punctuation? char-graphic?
syntax keyword racketFunc char-whitespace? char-blank?
syntax keyword racketFunc char-iso-control? char-general-category
syntax keyword racketFunc make-known-char-range-list
syntax keyword racketFunc char-upcase char-downcase char-titlecase char-foldcase

" 3.6 Symbols
syntax keyword racketFunc symbol? symbol-interned? symbol-unreadable?
syntax keyword racketFunc symbol->string string->symbol
syntax keyword racketFunc string->uninterned-symbol string->unreadable-symbol
syntax keyword racketFunc gensym

" 3.7 Regular Expressions
syntax keyword racketFunc regexp? pregexp? byte-regexp? byte-pregexp?
syntax keyword racketFunc regexp pregexp byte-regexp byte-pregexp
syntax keyword racketFunc regexp-quote regexp-match regexp-match*
syntax keyword racketFunc regexp-try-match regexp-match-positions
syntax keyword racketFunc regexp-match-positions* regexp-match?
syntax keyword racketFunc regexp-match-peek-positions regexp-match-peek-immediate
syntax keyword racketFunc regexp-match-peek regexp-match-peek-positions*
syntax keyword racketFunc regexp-match/end regexp-match-positions/end
syntax keyword racketFunc regexp-match-peek-positions-immediat/end
syntax keyword racketFunc regexp-split regexp-replace regexp-replace*
syntax keyword racketFunc regexp-replace-quote

" 3.8 Keywords
syntax keyword racketFunc keyword? keyword->string string->keyword keyword<?

" 3.9 Pairs and Lists
syntax keyword racketFunc pair? null? cons car cdr null
syntax keyword racketFunc list? list list* build-list length
syntax keyword racketFunc list-ref list-tail append reverse map andmap ormap
syntax keyword racketFunc for-each foldl foldr filter remove remq remv remove*
syntax keyword racketFunc remq* remv* sort member memv memq memf
syntax keyword racketFunc findf assoc assv assq assf
syntax keyword racketFunc caar cadr cdar cddr caaar caadr cadar caddr cdaar
syntax keyword racketFunc cddar cdddr caaaar caaadr caadar caaddr cadadr caddar
syntax keyword racketFunc cadddr cdaaar cdaadr cdadar cddaar cdddar cddddr

" 3.9.7 Additional List Functions and Synonyms
" (require racket/list)
syntax keyword racketFunc empty cons? empty? first rest
syntax keyword racketFunc second third fourth fifth sixth seventh eighth ninth tenth
syntax keyword racketFunc last last-pair make-list take drop split-at
syntax keyword racketFunc take-right drop-right split-at-right add-between
syntax keyword racketFunc append* flatten remove-duplicates filter-map
syntax keyword racketFunc count partition append-map filter-not shuffle
syntax keyword racketFunc argmin argmax make-reader-graph placeholder? make-placeholder
syntax keyword racketFunc placeholder-set! placeholder-get hash-placeholder?
syntax keyword racketFunc make-hash-placeholder make-hasheq-placeholder
syntax keyword racketFunc make-hasheqv-placeholder make-immutable-hasheqv

" 3.10 Mutable Pairs and Lists
syntax keyword racketFunc mpair? mcons mcar mcdr

" 3.11 Vectors
syntax keyword racketFunc vector?  make-vector vector vector-immutable vector-length
syntax keyword racketFunc vector-ref vector-set!  vector->list list->vector
syntax keyword racketFunc vector->immutable-vector vector-fill!  vector-copy!
syntax keyword racketFunc vector->values build-vector vector-set*!  vector-map
syntax keyword racketFunc vector-map!  vector-append vector-take vector-take-right
syntax keyword racketFunc vector-drop vector-drop-right vector-split-at
syntax keyword racketFunc vector-split-at-right vector-copy vector-filter
syntax keyword racketFunc vector-filter-not vector-count vector-argmin vector-argmax
syntax keyword racketFunc vector-member vector-memv vector-memq

" 3.12 Boxes
syntax keyword racketFunc box?  box box-immutable unbox set-box!

" 3.13 Hash Tables
syntax keyword racketFunc hash? hash-equal? hash-eqv? hash-eq? hash-weak? hash
syntax keyword racketFunc hasheq hasheqv
syntax keyword racketFunc make-hash make-hasheqv make-hasheq make-weak-hash make-weak-hasheqv
syntax keyword racketFunc make-weak-hasheq make-immutable-hash make-immutable-hasheqv
syntax keyword racketFunc make-immutable-hasheq
syntax keyword racketFunc hash-set! hash-set*! hash-set hash-set* hash-ref hash-ref!
syntax keyword racketFunc hash-has-key? hash-update! hash-update hash-remove!
syntax keyword racketFunc hash-remove hash-map hash-keys hash-values
syntax keyword racketFunc hash->list hash-for-each hash-count
syntax keyword racketFunc hash-iterate-first hash-iterate-next hash-iterate-key
syntax keyword racketFunc hash-iterate-value hash-copy eq-hash-code eqv-hash-code
syntax keyword racketFunc equal-hash-code equal-secondary-hash-code

" 3.15 Dictionaries
syntax keyword racketFunc dict? dict-mutable? dict-can-remove-keys? dict-can-functional-set?
syntax keyword racketFunc dict-set! dict-set*! dict-set dict-set* dict-has-key? dict-ref
syntax keyword racketFunc dict-ref! dict-update! dict-update dict-remove! dict-remove
syntax keyword racketFunc dict-map dict-for-each dict-count dict-iterate-first dict-iterate-next
syntax keyword racketFunc dict-iterate-key dict-iterate-value in-dict in-dict-keys
syntax keyword racketFunc in-dict-values in-dict-pairs dict-keys dict-values
syntax keyword racketFunc dict->list prop: dict prop: dict/contract dict-key-contract
syntax keyword racketFunc dict-value-contract dict-iter-contract make-custom-hash
syntax keyword racketFunc make-immutable-custom-hash make-weak-custom-hash

" 3.16 Sets
syntax keyword racketFunc set seteqv seteq set-empty? set-count set-member?
syntax keyword racketFunc set-add set-remove set-union set-intersect set-subtract
syntax keyword racketFunc set-symmetric-difference set=? subset? proper-subset?
syntax keyword racketFunc set-map set-for-each set? set-equal? set-eqv? set-eq?
syntax keyword racketFunc set/c in-set for/set for/seteq for/seteqv for*/set
syntax keyword racketFunc for*/seteq for*/seteqv list->set list->seteq
syntax keyword racketFunc list->seteqv set->list

" 3.17 Procedures
syntax keyword racketFunc procedure? apply compose compose1 procedure-rename procedure->method
syntax keyword racketFunc keyword-apply procedure-arity procedure-arity?
syntax keyword racketFunc procedure-arity-includes? procedure-reduce-arity
syntax keyword racketFunc procedure-keywords make-keyword-procedure
syntax keyword racketFunc procedure-reduce-keyword-arity procedure-struct-type?
syntax keyword racketFunc procedure-extract-target checked-procedure-check-and-extract
syntax keyword racketFunc primitive? primitive-closure? primitive-result-arity
syntax keyword racketFunc identity const thunk thunk* negate curry curryr

" 3.18 Void
syntax keyword racketFunc void void?

" 4.1 Defining Structure Types
syntax keyword racketFunc struct struct-field-index define-struct define-struct define-struct/derived

" 4.2 Creating Structure Types
syntax keyword racketFunc make-struct-type make-struct-field-accessor make-struct-field-mutator

" 4.3 Structure Type Properties
syntax keyword racketFunc make-struct-type-property struct-type-property? struct-type-property-accessor-procedure?

" 4.4 Copying and Updating Structures
syntax keyword racketFunc struct-copy

" 4.5 Structure Utilities
syntax keyword racketFunc struct->vector struct? struct-type?
syntax keyword racketFunc struct-constructor-procedure? struct-predicate-procedure? struct-accessor-procedure? struct-mutator-procedure?
syntax keyword racketFunc prefab-struct-key make-prefab-struct prefab-key->struct-type

" 4.6 Structure Type Transformer Binding
syntax keyword racketFunc struct-info? check-struct-info? make-struct-info extract-struct-info
syntax keyword racketFunc struct-auto-info? struct-auto-info-lists

" 5.1 Creating Interfaces
syntax keyword racketFunc interface interface*

" 5.2 Creating Classes
syntax keyword racketFunc class* class inspect
syntax keyword racketFunc init init-field field inherit field init-rest
syntax keyword racketFunc public public* pubment pubment* public-final public-final*
syntax keyword racketFunc override override* overment overment* override-final override-final*
syntax keyword racketFunc augride augride* augment augment* augment-final augment-final*
syntax keyword racketFunc abstract inherit inherit/super inherit/inner
syntax keyword racketFunc rename-inner rename-super
syntax keyword racketFunc define/public define/pubment define/public-final
syntax keyword racketFunc define/override define/overment define/override-final
syntax keyword racketFunc define/augride define/augment define/augment-final
syntax keyword racketFunc private* define/private

" 5.2.3 Methods
syntax keyword racketFunc class/derived
syntax keyword racketFunc super inner define-local-member-name define-member-name
syntax keyword racketFunc member-name-key generate-member-key member-name-key?
syntax keyword racketFunc member-name-key=? member-name-key-hash-code

" 5.3 Creating Objects
syntax keyword racketFunc make-object instantiate new
syntax keyword racketFunc super-make-object super-instantiate super-new

"5.4 Field and Method Access
syntax keyword racketFunc method-id send send/apply send/keyword-apply dynamic-send send*
syntax keyword racketFunc get-field set-field! field-bound?
syntax keyword racketFunc class-field-accessor class-field-mutator

"5.4.3 Generics
syntax keyword racketFunc generic send-generic make-generic

" 8.1 Data-strucure contracts
syntax keyword racketFunc flat-contract-with-explanation flat-named-contract
" TODO where do any/c and none/c `value`s go?
syntax keyword racketFunc or/c first-or/c and/c not/c =/c </c >/c <=/c >=/c
syntax keyword racketFunc between/c real-in integer-in char-in natural-number/c
syntax keyword racketFunc string-len/c printable/c one-of/c symbols vectorof
syntax keyword racketFunc vector-immutableof vector/c box/c box-immutable/c listof
syntax keyword racketFunc non-empty-listof list*of cons/c cons/dc list/c *list/c
syntax keyword racketFunc syntax/c struct/c struct/dc parameter/c
syntax keyword racketFunc procedure-arity-includes/c hash/c hash/dc channel/c
syntax keyword racketFunc prompt-tag/c continuation-mark-key/c evt/c promise/c
syntax keyword racketFunc flat-contract flat-contract-predicate suggest/c

" 9.1 Multiple Values
syntax keyword racketFunc values call-with-values

" 10.2.2 Raising Exceptions
syntax keyword racketFunc raise error raise-user-error raise-argument-error
syntax keyword racketFunc raise-result-error raise-argument-error raise-range-error
syntax keyword racketFunc raise-type-error raise-mismatch-error raise-arity-error
syntax keyword racketFunc raise-syntax-error

" 10.2.3 Handling Exceptions
syntax keyword racketFunc call-with-exception-handler uncaught-exception-handler

" 10.2.4 Configuring Default Handlers
syntax keyword racketFunc error-escape-handler error-display-handler error-print-width
syntax keyword racketFunc error-print-context-length error-values->string-handler
syntax keyword racketFunc error-print-source-location

" 10.2.5 Built-in Exception Types
syntax keyword racketFunc exn exn:fail exn:fail:contract exn:fail:contract:arity
syntax keyword racketFunc exn:fail:contract:divide-by-zero exn:fail:contract:non-fixnum-result
syntax keyword racketFunc exn:fail:contract:continuation exn:fail:contract:variable
syntax keyword racketFunc exn:fail:syntax exn:fail:syntax:unbound exn:fail:syntax:missing-module
syntax keyword racketFunc exn:fail:read exn:fail:read:eof exn:fail:read:non-char
syntax keyword racketFunc exn:fail:filesystem exn:fail:filesystem:exists
syntax keyword racketFunc exn:fail:filesystem:version exn:fail:filesystem:errno
syntax keyword racketFunc exn:fail:filesystem:missing-module
syntax keyword racketFunc exn:fail:network exn:fail:network:errno exn:fail:out-of-memory
syntax keyword racketFunc exn:fail:unsupported exn:fail:user
syntax keyword racketFunc exn:break exn:break:hang-up exn:break:terminate

" 10.3 Delayed Evaluation
syntax keyword racketFunc promise? delay lazy force promise-forced? promise-running?

" 10.3.1 Additional Promise Kinds
syntax keyword racketFunc delay/name promise/name delay/strict delay/sync delay/thread delay/idle

" 10.4 Continuations
syntax keyword racketFunc call-with-continuation-prompt abort-current-continuation make-continuation-prompt-tag
syntax keyword racketFunc default-continuation-prompt-tag call-with-current-continuation call/cc
syntax keyword racketFunc call-with-composable-continuation call-with-escape-continuation call/ec
syntax keyword racketFunc call-with-continuation-barrier continuation-prompt-available
syntax keyword racketFunc continuation? continuation-prompt-tag dynamic-wind

" 10.4.1 Additional Control Operators
syntax keyword racketFunc call/prompt abort/cc call/comp abort fcontrol spawn splitter new-prompt

" 11.3.2 Parameters
syntax keyword racketFunc make-parameter make-derived-parameter parameter?
syntax keyword racketFunc parameter-procedure=? current-parameterization
syntax keyword racketFunc call-with-parameterization parameterization?

" 14.1.1 Manipulating Paths
syntax keyword racketFunc path? path-string? path-for-some-system? string->path path->string path->bytes
syntax keyword racketFunc string->path-element bytes->path-element path-element->string path-element->bytes
syntax keyword racketFunc path-convention-type system-path-convention-type build-type
syntax keyword racketFunc build-type/convention-type
syntax keyword racketFunc absolute-path? relative-path? complete-path?
syntax keyword racketFunc path->complete-path path->directory-path
syntax keyword racketFunc resolve-path cleanse-path expand-user-path simplify-path normal-case-path split-path
syntax keyword racketFunc path-replace-suffix path-add-suffix

" 14.1.2 More Path Utilities
syntax keyword racketFunc explode-path file-name-from-path filename-extension find-relative-path normalize-path
syntax keyword racketFunc path-element? path-only simple-form-path some-simple-path->string string->some-system-path

" 15.6 Time
syntax keyword racketFunc current-seconds current-inexact-milliseconds
syntax keyword racketFunc seconds->date current-milliseconds


syntax match racketDelimiter !\<\.\>!

syntax cluster racketTop contains=racketSyntax,racketFunc,racketDelimiter

syntax match racketConstant  ,\<\*\k\+\*\>,
syntax match racketConstant  ,\<<\k\+>\>,

" Non-quoted lists, and strings
syntax region racketStruc matchgroup=racketParen start="("rs=s+1 end=")"re=e-1 contains=@racketTop
syntax region racketStruc matchgroup=racketParen start="#("rs=s+2 end=")"re=e-1 contains=@racketTop
syntax region racketStruc matchgroup=racketParen start="{"rs=s+1 end="}"re=e-1 contains=@racketTop
syntax region racketStruc matchgroup=racketParen start="#{"rs=s+2 end="}"re=e-1 contains=@racketTop
syntax region racketStruc matchgroup=racketParen start="\["rs=s+1 end="\]"re=e-1 contains=@racketTop
syntax region racketStruc matchgroup=racketParen start="#\["rs=s+2 end="\]"re=e-1 contains=@racketTop

for lit in ['hash', 'hasheq', 'hasheqv']
  execute printf('syntax match racketLit "\<%s\>" nextgroup=@racketParen containedin=ALLBUT,.*String,.*Comment', '#'.lit)
endfor

for lit in ['rx', 'rx#', 'px', 'px#']
  execute printf('syntax match racketRe "\<%s\>" nextgroup=@racketString containedin=ALLBUT,.*String,.*Comment,', '#'.lit)
endfor

unlet lit

" Simple literals

" Strings

syntax match racketStringEscapeError "\\." contained display

syntax match racketStringEscape "\\[abtnvfre'"\\]"        contained display
syntax match racketStringEscape "\\$"                     contained display
syntax match racketStringEscape "\\\o\{1,3}\|\\x\x\{1,2}" contained display

syntax match racketUStringEscape "\\u\x\{1,4}\|\\U\x\{1,8}" contained display
syntax match racketUStringEscape "\\u\x\{4}\\u\x\{4}"       contained display

syntax region racketString start=/\%(\\\)\@<!"/ skip=/\\[\\"]/ end=/"/ contains=racketStringEscapeError,racketStringEscape,racketUStringEscape
syntax region racketString start=/#"/           skip=/\\[\\"]/ end=/"/ contains=racketStringEscapeError,racketStringEscape

if exists("racket_no_string_fold")
  syn region racketHereString start=/#<<\z(.*\)$/ end=/^\z1$/
else
  syn region racketHereString start=/#<<\z(.*\)$/ end=/^\z1$/ fold
endif


syntax cluster racketTop  add=racketError,racketConstant,racketStruc,racketString,racketHereString

" Numbers

" anything which doesn't match the below rules, but starts with a #d, #b, #o,
" #x, #i, or #e, is an error
syntax match racketNumberError         "\<#[xdobie]\k*"

syntax match racketContainedNumberError   "\<#o\k*[^-+0-7delfinas#./@]\>"
syntax match racketContainedNumberError   "\<#b\k*[^-+01delfinas#./@]\>"
syntax match racketContainedNumberError   "\<#[ei]#[ei]"
syntax match racketContainedNumberError   "\<#[xdob]#[xdob]"

" start with the simpler sorts
syntax match racketNumber    "\<\(#[dobie]\)\{0,2}[-+]\?\(\d\+\|\d\+#*\.\|\d*\.\d\+\)#*\(/\d\+#*\)\?\([sdlef][-+]\?\d\+#*\)\?\>" contains=racketContainedNumberError
syntax match racketNumber    "\<\(#[dobie]\)\{0,2}[-+]\?\d\+/\d\+\>" contains=racketContainedNumberError
syntax match racketNumber    "\<\(#[dobie]\)\{0,2}[-+]\?\d\+/\d\+[-+]\d\+\(/\d\+\)\?i\>" contains=racketContainedNumberError

" different possible ways of expressing complex values
syntax match racketNumber    "\<\(#[dobie]\)\{0,2}[-+]\(\d\+\|\d\+#*\.\|\d*\.\d\+\)#*\(/\d\+#*\)\?\([sdlef][-+]\?\d\+#*\)\?i\>" contains=racketContainedNumberError
syntax match racketNumber    "\<\(#[dobie]\)\{0,2}[-+]\?\(\d\+\|\d\+#*\.\|\d*\.\d\+\)#*\(/\d\+#*\)\?\([sdlef][-+]\?\d\+#*\)\?[-+]\(\d\+\|\d\+#*\.\|\d*\.\d\+\)#*\(/\d\+#*\)\?\([sdlef][-+]\?\d\+#*\)\?i\>" contains=racketContainedNumberError
syntax match racketNumber    "\<\(#[dobie]\)\{0,2}[-+]\(inf\|nan\)\.[0f][-+]\(\d\+\|\d\+#*\.\|\d*\.\d\+\)#*\(/\d\+#*\)\?\([sdlef][-+]\?\d\+#*\)\?i\>" contains=racketContainedNumberError
syntax match racketNumber    "\<\(#[dobie]\)\{0,2}[-+]\?\(\d\+\|\d\+#*\.\|\d*\.\d\+\)#*\(/\d\+#*\)\?\([sdlef][-+]\?\d\+#*\)\?[-+]\(inf\|nan\)\.[0f]i\>" contains=racketContainedNumberError
syntax match racketNumber    "\<\(#[dobie]\)\{0,2}[-+]\?\(\d\+\|\d\+#*\.\|\d*\.\d\+\)#*\(/\d\+#*\)\?\([sdlef][-+]\?\d\+#*\)\?@[-+]\?\(\d\+\|\d\+#*\.\|\d*\.\d\+\)#*\(/\d\+#*\)\?\([sdlef][-+]\?\d\+#*\)\?\>" contains=racketContainedNumberError
syntax match racketNumber    "\<\(#[dobie]\)\{0,2}[-+]\(inf\|nan\)\.[0f]@[-+]\?\(\d\+\|\d\+#*\.\|\d*\.\d\+\)#*\(/\d\+#*\)\?\([sdlef][-+]\?\d\+#*\)\?\>" contains=racketContainedNumberError
syntax match racketNumber    "\<\(#[dobie]\)\{0,2}[-+]\?\(\d\+\|\d\+#*\.\|\d*\.\d\+\)#*\(/\d\+#*\)\?\([sdlef][-+]\?\d\+#*\)\?@[-+]\(inf\|nan\)\.[0f]\>" contains=racketContainedNumberError

" hex versions of the above (separate because of the different possible exponent markers)
syntax match racketNumber    "\<\(#x\|#[ei]#x\|#x#[ei]\)[-+]\?\(\x\+\|\x\+#*\.\|\x*\.\x\+\)#*\(/\x\+#*\)\?\([sl][-+]\?\x\+#*\)\?\>"
syntax match racketNumber    "\<\(#x\|#[ei]#x\|#x#[ei]\)[-+]\?\x\+/\x\+\>"
syntax match racketNumber    "\<\(#x\|#[ei]#x\|#x#[ei]\)[-+]\?\x\+/\x\+[-+]\x\+\(/\x\+\)\?i\>"

syntax match racketNumber    "\<\(#x\|#[ei]#x\|#x#[ei]\)[-+]\(\x\+\|\x\+#*\.\|\x*\.\x\+\)#*\(/\x\+#*\)\?\([sl][-+]\?\x\+#*\)\?i\>"
syntax match racketNumber    "\<\(#x\|#[ei]#x\|#x#[ei]\)[-+]\?\(\x\+\|\x\+#*\.\|\x*\.\x\+\)#*\(/\x\+#*\)\?\([sl][-+]\?\x\+#*\)\?[-+]\(\x\+\|\x\+#*\.\|\x*\.\x\+\)#*\(/\x\+#*\)\?\([sl][-+]\?\x\+#*\)\?i\>"
syntax match racketNumber    "\<\(#x\|#[ei]#x\|#x#[ei]\)[-+]\(inf\|nan\)\.[0f][-+]\(\x\+\|\x\+#*\.\|\x*\.\x\+\)#*\(/\x\+#*\)\?\([sl][-+]\?\x\+#*\)\?i\>"
syntax match racketNumber    "\<\(#x\|#[ei]#x\|#x#[ei]\)[-+]\?\(\x\+\|\x\+#*\.\|\x*\.\x\+\)#*\(/\x\+#*\)\?\([sl][-+]\?\x\+#*\)\?[-+]\(inf\|nan\)\.[0f]i\>"
syntax match racketNumber    "\<\(#x\|#[ei]#x\|#x#[ei]\)[-+]\?\(\x\+\|\x\+#*\.\|\x*\.\x\+\)#*\(/\x\+#*\)\?\([sl][-+]\?\x\+#*\)\?@[-+]\?\(\x\+\|\x\+#*\.\|\x*\.\x\+\)#*\(/\x\+#*\)\?\([sl][-+]\?\x\+#*\)\?\>"
syntax match racketNumber    "\<\(#x\|#[ei]#x\|#x#[ei]\)[-+]\(inf\|nan\)\.[0f]@[-+]\?\(\x\+\|\x\+#*\.\|\x*\.\x\+\)#*\(/\x\+#*\)\?\([sl][-+]\?\x\+#*\)\?\>"
syntax match racketNumber    "\<\(#x\|#[ei]#x\|#x#[ei]\)[-+]\?\(\x\+\|\x\+#*\.\|\x*\.\x\+\)#*\(/\x\+#*\)\?\([sl][-+]\?\x\+#*\)\?@[-+]\(inf\|nan\)\.[0f]\>"

" these work for any radix
syntax match racketNumber    "\<\(#[xdobie]\)\{0,2}[-+]\(inf\|nan\)\.[0f]i\?\>" contains=racketContainedNumberError
syntax match racketNumber    "\<\(#[xdobie]\)\{0,2}[-+]\(inf\|nan\)\.[0f][-+]\(inf\|nan\)\.[0f]i\>" contains=racketContainedNumberError
syntax match racketNumber    "\<\(#[xdobie]\)\{0,2}[-+]\(inf\|nan\)\.[0f]@[-+]\(inf\|nan\)\.[0f]\>" contains=racketContainedNumberError

syntax keyword racketBoolean  #t #f #true #false #T #F

syntax match racketError   "\<#\\\k*\>"

syntax match racketChar    "\<#\\.\w\@!"
syntax match racketChar    "\<#\\space\>"
syntax match racketChar    "\<#\\newline\>"
syntax match racketChar    "\<#\\return\>"
syntax match racketChar    "\<#\\null\?\>"
syntax match racketChar    "\<#\\backspace\>"
syntax match racketChar    "\<#\\tab\>"
syntax match racketChar    "\<#\\linefeed\>"
syntax match racketChar    "\<#\\vtab\>"
syntax match racketChar    "\<#\\page\>"
syntax match racketChar    "\<#\\rubout\>"
syntax match racketChar    "\<#\\\o\{1,3}\>"
syntax match racketChar    "\<#\\x\x\{1,2}\>"
syntax match racketChar    "\<#\\u\x\{1,6}\>"

syntax cluster racketTop  add=racketNumber,racketBoolean,racketChar

" Command-line parsing
syntax keyword racketExtFunc command-line current-command-line-arguments once-any help-labels multi once-each

syntax match racketSyntax    "#lang "
syntax match racketExtSyntax "#:\k\+"

syntax cluster racketTop  add=racketExtFunc,racketExtSyntax

" syntax quoting, unquoting and quasiquotation
syntax match racketQuote "#\?['`]"

syntax match racketUnquote "#,"
syntax match racketUnquote "#,@"
syntax match racketUnquote ","
syntax match racketUnquote ",@"

" Comments
syntax match racketSharpBang "\%^#![ /].*" display
syntax match racketComment /;.*$/ contains=racketTodo,racketNote,@Spell
syntax region racketMultilineComment start=/#|/ end=/|#/ contains=racketMultilineComment,racketTodo,racketNote,@Spell
syntax match racketFormComment "#;" nextgroup=@racketTop

syntax match racketTodo /\C\<\(FIXME\|TODO\|XXX\)\ze:\?\>/ contained
syntax match racketNote /\CNOTE\ze:\?/ contained

syntax cluster racketTop  add=racketQuote,racketUnquote,racketComment,racketMultilineComment,racketFormComment

" Synchronization and the wrapping up...
syntax sync match matchPlace grouphere NONE "^[^ \t]"
" ... i.e. synchronize on a line that starts at the left margin

" Define the default highlighting.
highlight default link racketSyntax Statement
highlight default link racketFunc Function

highlight default link racketString String
highlight default link racketStringEscape Special
highlight default link racketHereString String
highlight default link racketUStringEscape Special
highlight default link racketStringEscapeError Error
highlight default link racketChar Character
highlight default link racketBoolean Boolean

highlight default link racketNumber Number
highlight default link racketNumberError Error
highlight default link racketContainedNumberError Error

highlight default link racketQuote SpecialChar
highlight default link racketUnquote SpecialChar

highlight default link racketDelimiter Delimiter
highlight default link racketParen Delimiter
highlight default link racketConstant Constant

highlight default link racketLit Type
highlight default link racketRe Type

highlight default link racketComment Comment
highlight default link racketMultilineComment Comment
highlight default link racketFormComment SpecialChar
highlight default link racketSharpBang Comment
highlight default link racketTodo Todo
highlight default link racketNote SpecialComment
highlight default link racketError Error

highlight default link racketExtSyntax Type
highlight default link racketExtFunc PreProc

let b:current_syntax = "racket"
