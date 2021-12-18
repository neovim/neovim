" Vim syntax file
" Language:      Raku
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Homepage:      https://github.com/Raku/vim-raku
" Bugs/requests: https://github.com/Raku/vim-raku/issues
" Last Change:   2021-04-16

" Contributors:  Luke Palmer <fibonaci@babylonia.flatirons.org>
"                Moritz Lenz <moritz@faui2k3.org>
"                Hinrik Örn Sigurðsson <hinrik.sig@gmail.com>
"
" This is a big undertaking.
"
" The ftdetect/raku.vim file in this repository takes care of setting the
" right filetype for Raku files. To set it explicitly you can also add this
" line near the bottom of your source file:
"   # vim: filetype=raku

" TODO:
"   * Go over the list of keywords/types to see what's deprecated/missing
"   * Add more support for folding (:help syn-fold)
"
" If you want to have Pir code inside Q:PIR// strings highlighted, do:
"   let raku_embedded_pir=1
"
" The above requires pir.vim, which you can find in Parrot's repository:
" https://github.com/parrot/parrot/tree/master/editor
"
" To highlight Perl 5 regexes (m:P5//):
"   let raku_perl5_regexes=1
"
" To enable folding:
"   let raku_fold=1

if version < 704 | throw "raku.vim uses regex syntax which Vim <7.4 doesn't support. Try 'make fix_old_vim' in the vim-perl repository." | endif

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
    syntax clear
elseif exists("b:current_syntax")
    finish
endif
let s:keepcpo= &cpo
set cpo&vim

" Patterns which will be interpolated by the preprocessor (tools/preproc.pl):
"
" @@IDENT_NONDIGIT@@     "[A-Za-z_\xC0-\xFF]"
" @@IDENT_CHAR@@         "[A-Za-z_\xC0-\xFF0-9]"
" @@IDENTIFIER@@         "\%(@@IDENT_NONDIGIT@@\%(@@IDENT_CHAR@@\|[-']@@IDENT_NONDIGIT@@\@=\)*\)"
" @@IDENTIFIER_START@@   "@@IDENT_CHAR@@\@1<!\%(@@IDENT_NONDIGIT@@[-']\)\@2<!"
" @@IDENTIFIER_END@@     "\%(@@IDENT_CHAR@@\|[-']@@IDENT_NONDIGIT@@\)\@!"
" @@METAOP@@             #\%(\d\|[@%$][.?^=[:alpha:]]\)\@!\%(\.\|[^[{('".[:space:]]\)\+#
" @@ADVERBS@@            "\%(\_s*:!\?@@IDENTIFIER@@\%(([^)]*)\)\?\)*"
"
" Same but escaped, for use in string eval
" @@IDENT_NONDIGIT_Q@@   "[A-Za-z_\\xC0-\\xFF]"
" @@IDENT_CHAR_Q@@       "[A-Za-z_\\xC0-\\xFF0-9]"
" @@IDENTIFIER_Q@@       "\\%(@@IDENT_NONDIGIT_Q@@\\%(@@IDENT_CHAR_Q@@\\|[-']@@IDENT_NONDIGIT_Q@@\\@=\\)*\\)"
" @@IDENTIFIER_START_Q@@ "@@IDENT_CHAR_Q@@\\@1<!\\%(@@IDENT_NONDIGIT_Q@@[-']\\)\\@2<!"
" @@IDENTIFIER_END_Q@@   "\\%(@@IDENT_CHAR_Q@@\\|[-']@@IDENT_NONDIGIT_Q@@\\)\\@!"

" Identifiers (subroutines, methods, constants, classes, roles, etc)
syn match rakuIdentifier display "\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"

let s:keywords = {
 \ "rakuInclude": [
 \   "use require import unit",
 \ ],
 \ "rakuConditional": [
 \   "if else elsif unless with orwith without once",
 \ ],
 \ "rakuVarStorage": [
 \   "let my our state temp has constant",
 \ ],
 \ "rakuRepeat": [
 \   "for loop repeat while until gather given",
 \   "supply react race hyper lazy quietly",
 \ ],
 \ "rakuFlowControl": [
 \   "take take-rw do when next last redo return return-rw",
 \   "start default exit make continue break goto leave",
 \   "proceed succeed whenever emit done",
 \ ],
 \ "rakuClosureTrait": [
 \   "BEGIN CHECK INIT FIRST ENTER LEAVE KEEP",
 \   "UNDO NEXT LAST PRE POST END CATCH CONTROL",
 \   "DOC QUIT CLOSE COMPOSE",
 \ ],
 \ "rakuException": [
 \   "die fail try warn",
 \ ],
 \ "rakuPragma": [
 \   "MONKEY-GUTS MONKEY-SEE-NO-EVAL MONKEY-TYPING MONKEY",
 \   "experimental fatal isms lib newline nqp precompilation",
 \   "soft strict trace variables worries",
 \ ],
 \ "rakuOperator": [
 \   "div xx x mod also leg cmp before after eq ne le lt not",
 \   "gt ge eqv ff fff and andthen or xor orelse lcm gcd o",
 \   "unicmp notandthen minmax",
 \ ],
 \ "rakuType": [
 \   "int int1 int2 int4 int8 int16 int32 int64",
 \   "rat rat1 rat2 rat4 rat8 rat16 rat32 rat64",
 \   "buf buf1 buf2 buf4 buf8 buf16 buf32 buf64",
 \   "blob blob1 blob2 blob4 blob8 blob16 blob32 blob64",
 \   "uint uint1 uint2 uint4 uint8 uint16 uint32 bit bool",
 \   "uint64 utf8 utf16 utf32 bag set mix complex",
 \   "num num32 num64 long longlong Pointer size_t str void",
 \   "ulong ulonglong ssize_t atomicint",
 \ ],
\ }

" These can be immediately followed by parentheses
let s:types = [
 \ "Object Any Cool Junction Whatever Capture Match",
 \ "Signature Proxy Matcher Package Module Class",
 \ "Grammar Scalar Array Hash KeyHash KeySet KeyBag",
 \ "Pair List Seq Range Set Bag Map Mapping Void Undef",
 \ "Failure Exception Code Block Routine Sub Macro",
 \ "Method Submethod Regex Str Blob Char Byte Parcel",
 \ "Codepoint Grapheme StrPos StrLen Version Num",
 \ "Complex Bit True False Order Same Less More",
 \ "Increasing Decreasing Ordered Callable AnyChar",
 \ "Positional Associative Ordering KeyExtractor",
 \ "Comparator OrderingPair IO KitchenSink Role",
 \ "Int Rat Buf UInt Abstraction Numeric Real",
 \ "Nil Mu SeekFromBeginning SeekFromEnd SeekFromCurrent",
\ ]

" We explicitly enumerate the alphanumeric infix operators allowed after [RSXZ]
" to avoid matching package names that start with those letters.
let s:alpha_metaops = [
 \ "div mod gcd lcm xx x does but cmp leg eq ne gt ge lt le before after eqv",
 \ "min max not so andthen and or orelse unicmp coll minmax",
\ ]
let s:words_space = join(s:alpha_metaops, " ")
let s:temp = split(s:words_space)
let s:alpha_metaops_or = join(s:temp, "\\|")

" We don't use "syn keyword" here because that always has higher priority
" than matches/regions, which would prevent these words from matching as
" autoquoted strings before "=>".
syn match rakuKeywordStart display "\%(\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\)\@!\)\@=[A-Za-z_\xC0-\xFF0-9]\@1<!\%([A-Za-z_\xC0-\xFF][-']\)\@2<!"
    \ nextgroup=rakuAttention,rakuVariable,rakuInclude,rakuConditional,rakuVarStorage,rakuRepeat,rakuFlowControl,rakuClosureTrait,rakuException,rakuNumber,rakuPragma,rakuType,rakuOperator,rakuIdentifier

for [s:group, s:words_list] in items(s:keywords)
    let s:words_space = join(s:words_list, " ")
    let s:temp = split(s:words_space)
    let s:words = join(s:temp, "\\|")
    exec "syn match ". s:group ." display \"[.^]\\@1<!\\%(". s:words . "\\)(\\@!\\%([A-Za-z_\\xC0-\\xFF0-9]\\|[-'][A-Za-z_\\xC0-\\xFF]\\)\\@!\" contained"
endfor

let s:words_space = join(s:types, " ")
let s:temp = split(s:words_space)
let s:words = join(s:temp, "\\|")
exec "syn match rakuType display \"\\%(". s:words . "\\)\\%([A-Za-z_\\xC0-\\xFF0-9]\\|[-'][A-Za-z_\\xC0-\\xFF]\\)\\@!\" contained"
unlet s:group s:words_list s:keywords s:types s:words_space s:temp s:words

syn match rakuPreDeclare display "[.^]\@1<!\<\%(multi\|proto\|only\)\>" nextgroup=rakuDeclare,rakuIdentifier skipwhite skipempty
syn match rakuDeclare display "[.^]\@1<!\<\%(macro\|sub\|submethod\|method\|module\|class\|role\|package\|enum\|grammar\|slang\|subset\)\>" nextgroup=rakuIdentifier skipwhite skipempty
syn match rakuDeclareRegex display "[.^]\@1<!\<\%(regex\|rule\|token\)\>" nextgroup=rakuRegexName skipwhite skipempty

syn match rakuTypeConstraint  display "\%([.^]\|^\s*\)\@<!\a\@=\%(does\|as\|but\|trusts\|of\|returns\|handles\|where\|augment\|supersede\)\>"
syn match rakuTypeConstraint  display "\%([.^]\|^\s*\)\@<![A-Za-z_\xC0-\xFF0-9]\@1<!\%([A-Za-z_\xC0-\xFF][-']\)\@2<!is\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\)\@!" skipwhite skipempty nextgroup=rakuProperty
syn match rakuProperty        display "\a\@=\%(signature\|context\|also\|shape\|prec\|irs\|ofs\|ors\|export\|deep\|binary\|unary\|reparsed\|rw\|parsed\|cached\|readonly\|defequiv\|will\|ref\|copy\|inline\|tighter\|looser\|equiv\|assoc\|required\|DEPRECATED\|raw\|repr\|dynamic\|hidden-from-backtrace\|nodal\|pure\)" contained

" packages, must come after all the keywords
syn match rakuIdentifier display "\%(::\)\@2<=\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)*"
syn match rakuIdentifier display "\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(::\)\@="

" The sigil in ::*Package
syn match rakuPackageTwigil display "\%(::\)\@2<=\*"

" some standard packages
syn match rakuType display "\%(::\)\@2<!\%(SeekType\%(::SeekFromBeginning\|::SeekFromCurrent\|::SeekFromEnd\)\|Order\%(::Same\|::More\|::Less\)\?\|Bool\%(::True\|::False\)\?\)\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\)\@!"

" Don't put a "\+" at the end of the character class. That makes it so
" greedy that the "%" " in "+%foo" won't be allowed to match as a sigil,
" among other things
syn match rakuOperator display "[-+/*~?|=^!%&,<>».;\\∈∉∋∌∩∪≼≽⊂⊃⊄⊅⊆⊇⊈⊉⊍⊎⊖∅∘]"
syn match rakuOperator display "\%(:\@1<!::\@2!\|::=\|\.::\)"
" these require whitespace on the left side
syn match rakuOperator display "\%(\s\|^\)\@1<=\%(xx=\)"
" index overloading
syn match rakuOperator display "\%(&\.(\@=\|@\.\[\@=\|%\.{\@=\)"

" Reduce metaoperators like [+]
syn match rakuReduceOp display "\%(^\|\s\|(\)\@1<=!*\%([RSXZ\[]\)*[&RSXZ]\?\[\+(\?\%(\d\|[@%$][.?^=[:alpha:]]\)\@!\%(\.\|[^[{('".[:space:]]\)\+)\?]\+"
syn match rakuSetOp    display "R\?(\%([-^.+|&]\|[<>][=+]\?\|cont\|elem\))"

" Reverse, cross, and zip metaoperators
exec "syn match rakuRSXZOp display \"[RSXZ]:\\@!\\%(\\a\\@=\\%(". s:alpha_metaops_or . "\\)\\>\\|[[:alnum:]]\\@!\\%([.,]\\|[^[,.[:alnum:][:space:]]\\)\\+\\|\\s\\@=\\|$\\)\""

syn match rakuBlockLabel display "^\s*\zs\h\w*\s*::\@!\_s\@="

syn match rakuNumber     display "[A-Za-z_\xC0-\xFF0-9]\@1<!\%(\%(\%(\_^\|\s\|[^*\a]\)\@1<=[-+]\)\?Inf\|NaN\)"
syn match rakuNumber     display "[A-Za-z_\xC0-\xFF0-9]\@1<!\%(\%(\_^\|\s\|[^*\a]\)\@1<=[-+]\)\?\%(\%(\d\|__\@!\)*[._]\@1<!\.\)\?_\@!\%(\d\|_\)\+_\@1<!\%([eE]-\?_\@!\%(\d\|_\)\+\)\?i\?"
syn match rakuNumber     display "[A-Za-z_\xC0-\xFF0-9]\@1<!\%(\%(\_^\|\s\|[^*\a]\)\@1<=[-+]\)\?0[obxd]\@="  nextgroup=rakuOctBase,rakuBinBase,rakuHexBase,rakuDecBase
syn match rakuOctBase    display "o" contained nextgroup=rakuOctNumber
syn match rakuBinBase    display "b" contained nextgroup=rakuBinNumber
syn match rakuHexBase    display "x" contained nextgroup=rakuHexNumber
syn match rakuDecBase    display "d" contained nextgroup=rakuDecNumber
syn match rakuOctNumber  display "[0-7][0-7_]*" contained
syn match rakuBinNumber  display "[01][01_]*" contained
syn match rakuHexNumber  display "\x[[:xdigit:]_]*" contained
syn match rakuDecNumber  display "\d[[:digit:]_]*" contained

syn match rakuVersion    display "\<v\d\+\%(\.\%(\*\|\d\+\)\)*+\?"

" Contextualizers
syn match rakuContext display "\<\%(item\|list\|slice\|hash\)\>"
syn match rakuContext display "\%(\$\|@\|%\|&\)(\@="

" Quoting

" one cluster for every quote adverb
syn cluster rakuInterp_scalar
    \ add=rakuInterpScalar

syn cluster rakuInterp_array
    \ add=rakuInterpArray

syn cluster rakuInterp_hash
    \ add=rakuInterpHash

syn cluster rakuInterp_function
    \ add=rakuInterpFunction

syn cluster rakuInterp_closure
    \ add=rakuInterpClosure

syn cluster rakuInterp_q
    \ add=rakuEscQQ
    \ add=rakuEscBackSlash

syn cluster rakuInterp_backslash
    \ add=@rakuInterp_q
    \ add=rakuEscape
    \ add=rakuEscOpenCurly
    \ add=rakuEscCodePoint
    \ add=rakuEscHex
    \ add=rakuEscOct
    \ add=rakuEscOctOld
    \ add=rakuEscNull

syn cluster rakuInterp_qq
    \ add=@rakuInterp_scalar
    \ add=@rakuInterp_array
    \ add=@rakuInterp_hash
    \ add=@rakuInterp_function
    \ add=@rakuInterp_closure
    \ add=@rakuInterp_backslash
    \ add=rakuMatchVarSigil

syn region rakuInterpScalar
    \ start="\ze\z(\$\%(\%(\%(\d\+\|!\|/\|¢\)\|\%(\%(\%([.^*?=!~]\|:\@1<!::\@!\)[A-Za-z_\xC0-\xFF]\@=\)\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\)\%(\.\^\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\|\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)*\)\.\?\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)\)"
    \ start="\ze\z(\$\%(\%(\%(\%([.^*?=!~]\|:\@1<!::\@!\)[A-Za-z_\xC0-\xFF]\@=\)\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\)\|\%(\d\+\|!\|/\|¢\)\)\)"
    \ end="\z1\zs"
    \ contained keepend
    \ contains=TOP

syn region rakuInterpScalar
    \ matchgroup=rakuContext
    \ start="\$\ze()\@!"
    \ skip="([^)]*)"
    \ end=")\zs"
    \ contained
    \ contains=TOP

syn region rakuInterpArray
    \ start="\ze\z(@\$*\%(\%(\%(!\|/\|¢\)\|\%(\%(\%([.^*?=!~]\|:\@1<!::\@!\)[A-Za-z_\xC0-\xFF]\@=\)\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\)\%(\.\^\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\|\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)*\)\.\?\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)\)"
    \ end="\z1\zs"
    \ contained keepend
    \ contains=TOP

syn region rakuInterpArray
    \ matchgroup=rakuContext
    \ start="@\ze()\@!"
    \ skip="([^)]*)"
    \ end=")\zs"
    \ contained
    \ contains=TOP

syn region rakuInterpHash
    \ start="\ze\z(%\$*\%(\%(\%(!\|/\|¢\)\|\%(\%(\%([.^*?=!~]\|:\@1<!::\@!\)[A-Za-z_\xC0-\xFF]\@=\)\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\)\%(\.\^\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\|\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)*\)\.\?\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)\)"
    \ end="\z1\zs"
    \ contained keepend
    \ contains=TOP

syn region rakuInterpHash
    \ matchgroup=rakuContext
    \ start="%\ze()\@!"
    \ skip="([^)]*)"
    \ end=")\zs"
    \ contained
    \ contains=TOP

syn region rakuInterpFunction
    \ start="\ze\z(&\%(\%(!\|/\|¢\)\|\%(\%(\%([.^*?=!~]\|:\@1<!::\@!\)[A-Za-z_\xC0-\xFF]\@=\)\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(\.\^\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\|\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)*\)\.\?\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)\)"
    \ end="\z1\zs"
    \ contained keepend
    \ contains=TOP

syn region rakuInterpFunction
    \ matchgroup=rakuContext
    \ start="&\ze()\@!"
    \ skip="([^)]*)"
    \ end=")\zs"
    \ contained
    \ contains=TOP

syn region rakuInterpClosure
    \ start="\\\@1<!{}\@!"
    \ skip="{[^}]*}"
    \ end="}"
    \ contained keepend
    \ contains=TOP

" generic escape
syn match rakuEscape          display "\\\S" contained

" escaped closing delimiters
syn match rakuEscQuote        display "\\'" contained
syn match rakuEscDoubleQuote  display "\\\"" contained
syn match rakuEscCloseAngle   display "\\>" contained
syn match rakuEscCloseFrench  display "\\»" contained
syn match rakuEscBackTick     display "\\`" contained
syn match rakuEscForwardSlash display "\\/" contained
syn match rakuEscVerticalBar  display "\\|" contained
syn match rakuEscExclamation  display "\\!" contained
syn match rakuEscComma        display "\\," contained
syn match rakuEscDollar       display "\\\$" contained
syn match rakuEscCloseCurly   display "\\}" contained
syn match rakuEscCloseBracket display "\\\]" contained

" matches :key, :!key, :$var, :key<var>, etc
" Since we don't know in advance how the adverb ends, we use a trick.
" Consume nothing with the start pattern (\ze at the beginning),
" while capturing the whole adverb into \z1 and then putting it before
" the match start (\zs) of the end pattern.
syn region rakuAdverb
    \ start="\ze\z(:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\?\)"
    \ start="\ze\z(:!\?[@$%]\$*\%(::\|\%(\$\@1<=\d\+\|!\|/\|¢\)\|\%(\%([.^*?=!~]\|:\@1<!::\@!\)[A-Za-z_\xC0-\xFF]\)\|\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\)\)"
    \ end="\z1\zs"
    \ contained keepend
    \ contains=TOP

" <words>
" Distinguishing this from the "less than" operator is tricky. For now,
" it matches if any of the following is true:
"
" * There is whitespace missing on either side of the "<", since
"   people tend to put spaces around "less than". We make an exception
"   for " = < ... >" assignments though.
" * It comes after "enum", "for", "any", "all", or "none"
" * It's the first or last thing on a line (ignoring whitespace)
" * It's preceded by "(\s*" or "=\s\+"
" * It's empty and terminated on the same line (e.g. <> and < >)
"
" It never matches when:
"
" * Preceded by [<+~=!] (e.g. <<foo>>, =<$foo>, * !< 3)
" * Followed by [-=] (e.g. <--, <=, <==, <->)
syn region rakuStringAngle
    \ matchgroup=rakuQuote
    \ start="\%(\<\%(enum\|for\|any\|all\|none\)\>\s*(\?\s*\)\@<=<\%(<\|=>\|\%([=-]\{1,2}>\|[=-]\{2}\)\)\@!"
    \ start="\%(\s\|[<+~=!]\)\@<!<\%(<\|=>\|\%([=-]\{1,2}>\|[=-]\{2}\)\)\@!"
    \ start="[<+~=!]\@1<!<\%(\s\|<\|=>\|\%([=-]\{1,2}>\|[=-]\{1,2}\)\)\@!"
    \ start="\%(^\s*\)\@<=<\%(<\|=>\|\%([=-]\{1,2}>\|[=-]\{2}\)\)\@!"
    \ start="[<+~=!]\@1<!<\%(\s*$\)\@="
    \ start="\%((\s*\|=\s\+\)\@<=<\%(<\|=>\|\%([=-]\{1,2}>\|[=-]\{2}\)\)\@!"
    \ start="<\%(\s*>\)\@="
    \ skip="\\\@1<!\\>"
    \ end=">"
    \ contains=rakuInnerAnglesOne,rakuEscBackSlash,rakuEscCloseAngle

syn region rakuStringAngleFixed
    \ matchgroup=rakuQuote
    \ start="<"
    \ skip="\\\@1<!\\>"
    \ end=">"
    \ contains=rakuInnerAnglesOne,rakuEscBackSlash,rakuEscCloseAngle
    \ contained

syn region rakuInnerAnglesOne
    \ matchgroup=rakuStringAngle
    \ start="\\\@1<!<"
    \ skip="\\\@1<!\\>"
    \ end=">"
    \ transparent contained
    \ contains=rakuInnerAnglesOne

" <<words>>
syn region rakuStringAngles
    \ matchgroup=rakuQuote
    \ start="<<=\@!"
    \ skip="\\\@1<!\\>"
    \ end=">>"
    \ contains=rakuInnerAnglesTwo,@rakuInterp_qq,rakuComment,rakuBracketComment,rakuEscHash,rakuEscCloseAngle,rakuAdverb,rakuStringSQ,rakuStringDQ

syn region rakuInnerAnglesTwo
    \ matchgroup=rakuStringAngles
    \ start="<<"
    \ skip="\\\@1<!\\>"
    \ end=">>"
    \ transparent contained
    \ contains=rakuInnerAnglesTwo

" «words»
syn region rakuStringFrench
    \ matchgroup=rakuQuote
    \ start="«"
    \ skip="\\\@1<!\\»"
    \ end="»"
    \ contains=rakuInnerFrench,@rakuInterp_qq,rakuComment,rakuBracketComment,rakuEscHash,rakuEscCloseFrench,rakuAdverb,rakuStringSQ,rakuStringDQ

syn region rakuInnerFrench
    \ matchgroup=rakuStringFrench
    \ start="\\\@1<!«"
    \ skip="\\\@1<!\\»"
    \ end="»"
    \ transparent contained
    \ contains=rakuInnerFrench

" Hyperops. They need to come after "<>" and "«»" strings in order to override
" them, but before other types of strings, to avoid matching those delimiters
" as parts of hyperops.
syn match rakuHyperOp display #[^[:digit:][{('",:[:space:]][^[{('",:[:space:]]*\%(«\|<<\)#
syn match rakuHyperOp display "«\%(\d\|[@%$][.?^=[:alpha:]]\)\@!\%(\.\|[^[{('".[:space:]]\)\+[«»]"
syn match rakuHyperOp display "»\%(\d\|[@%$][.?^=[:alpha:]]\)\@!\%(\.\|[^[{('".[:space:]]\)\+\%(«\|»\?\)"
syn match rakuHyperOp display "<<\%(\d\|[@%$][.?^=[:alpha:]]\)\@!\%(\.\|[^[{('".[:space:]]\)\+\%(<<\|>>\)"
syn match rakuHyperOp display ">>\%(\d\|[@%$][.?^=[:alpha:]]\)\@!\%(\.\|[^[{('".[:space:]]\)\+\%(<<\|\%(>>\)\?\)"

" 'string'
syn region rakuStringSQ
    \ matchgroup=rakuQuote
    \ start="'"
    \ skip="\\\@1<!\\'"
    \ end="'"
    \ contains=@rakuInterp_q,rakuEscQuote
    \ keepend extend

" "string"
syn region rakuStringDQ
    \ matchgroup=rakuQuote
    \ start=+"+
    \ skip=+\\\@1<!\\"+
    \ end=+"+
    \ contains=@rakuInterp_qq,rakuEscDoubleQuote
    \ keepend extend

" Q// and friends

syn match rakuQuoteQStart display "\%(:\|\%(sub\|role\)\s\)\@5<![Qq]\@=" nextgroup=rakuQuoteQ,rakuQuoteQ_q,rakuQuoteQ_qww,rakuQuoteQ_qq,rakuQuoteQ_to,rakuQuoteQ_qto,rakuQuoteQ_qqto,rakuIdentifier
syn match rakuQuoteQ      display "Q\%(qq\|ww\|[abcfhpsqvwx]\)\?[A-Za-z(]\@!" nextgroup=rakuPairsQ skipwhite skipempty contained
syn match rakuQuoteQ_q    display "q[abcfhpsvwx]\?[A-Za-z(]\@!" nextgroup=rakuPairsQ_q skipwhite skipempty contained
syn match rakuQuoteQ_qww  display "qww[A-Za-z(]\@!" nextgroup=rakuPairsQ_qww skipwhite skipempty contained
syn match rakuQuoteQ_qq   display "qq\%([pwx]\|ww\)\?[A-Za-z(]\@!" nextgroup=rakuPairsQ_qq skipwhite skipempty contained
syn match rakuQuoteQ_to   display "Qto[A-Za-z(]\@!" nextgroup=rakuStringQ_to skipwhite skipempty contained
syn match rakuQuoteQ_qto  display "qto[A-Za-z(]\@!" nextgroup=rakuStringQ_qto skipwhite skipempty contained
syn match rakuQuoteQ_qqto display "qqto[A-Za-z(]\@!" nextgroup=rakuStringQ_qqto skipwhite skipempty contained
syn match rakuQuoteQ_qto  display "q\_s*\%(\%(\_s*:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\)\?\)*:\%(to\|heredoc\)\%(\_s*:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\)\?\)*(\@!\)\@=" nextgroup=rakuPairsQ_qto skipwhite skipempty contained
syn match rakuQuoteQ_qqto display "qq\_s*\%(\%(\_s*:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\)\?\)*:\%(to\|heredoc\)\%(\_s*:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\)\?\)*(\@!\)\@=" nextgroup=rakuPairsQ_qqto skipwhite skipempty contained
syn match rakuPairsQ      "\%(\_s*:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\)\?\)*" contained transparent skipwhite skipempty nextgroup=rakuStringQ
syn match rakuPairsQ_q    "\%(\_s*:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\)\?\)*" contained transparent skipwhite skipempty nextgroup=rakuStringQ_q
syn match rakuPairsQ_qww  "\%(\_s*:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\)\?\)*" contained transparent skipwhite skipempty nextgroup=rakuStringQ_qww
syn match rakuPairsQ_qq   "\%(\_s*:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\)\?\)*" contained transparent skipwhite skipempty nextgroup=rakuStringQ_qq
syn match rakuPairsQ_qto  "\%(\_s*:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\)\?\)*" contained transparent skipwhite skipempty nextgroup=rakuStringQ_qto
syn match rakuPairsQ_qqto "\%(\_s*:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\)\?\)*" contained transparent skipwhite skipempty nextgroup=rakuStringQ_qqto


if exists("raku_embedded_pir") || exists("raku_extended_all")
    syn include @rakuPIR syntax/pir.vim
    syn match rakuQuote_QPIR display "Q[A-Za-z(]\@!\%(\_s*:PIR\)\@=" nextgroup=rakuPairsQ_PIR skipwhite skipempty
    syn match rakuPairs_QPIR contained "\_s*:PIR" transparent skipwhite skipempty nextgroup=rakuStringQ_PIR
endif

" hardcoded set of delimiters
let s:plain_delims = [
  \ ["DQ",          "\\\"",         "\\\"", "rakuEscDoubleQuote",  "\\\\\\@1<!\\\\\\\""],
  \ ["SQ",          "'",            "'",    "rakuEscQuote",        "\\\\\\@1<!\\\\'"],
  \ ["Slash",       "/",            "/",    "rakuEscForwardSlash", "\\\\\\@1<!\\\\/"],
  \ ["BackTick",    "`",            "`",    "rakuEscBackTick",     "\\\\\\@1<!\\\\`"],
  \ ["Bar",         "|",            "|",    "rakuEscVerticalBar",  "\\\\\\@1<!\\\\|"],
  \ ["Exclamation", "!",            "!",    "rakuEscExclamation",  "\\\\\\@1<!\\\\!"],
  \ ["Comma",       ",",            ",",    "rakuEscComma",        "\\\\\\@1<!\\\\,"],
  \ ["Dollar",      "\\$",          "\\$",  "rakuEscDollar",       "\\\\\\@1<!\\\\\\$"],
\ ]
let s:bracketing_delims = [
  \ ["Curly",   "{",            "}",    "rakuEscCloseCurly",   "\\%(\\\\\\@1<!\\\\}\\|{[^}]*}\\)"],
  \ ["Angle",   "<",            ">",    "rakuEscCloseAngle",   "\\%(\\\\\\@1<!\\\\>\\|<[^>]*>\\)"],
  \ ["French",  "«",            "»",    "rakuEscCloseFrench",  "\\%(\\\\\\@1<!\\\\»\\|«[^»]*»\\)"],
  \ ["Bracket", "\\\[",         "]",    "rakuEscCloseBracket", "\\%(\\\\\\@1<!\\\\]\\|\\[^\\]]*]\\)"],
  \ ["Paren",   "\\s\\@1<=(",   ")",    "rakuEscCloseParen",   "\\%(\\\\\\@1<!\\\\)\\|([^)]*)\\)"],
\ ]
let s:all_delims = s:plain_delims + s:bracketing_delims

for [s:name, s:start_delim, s:end_delim, s:end_group, s:skip] in s:all_delims
    exec "syn region rakuStringQ matchgroup=rakuQuote start=\"".s:start_delim."\" end=\"".s:end_delim."\" contained"
    exec "syn region rakuStringQ_q matchgroup=rakuQuote start=\"".s:start_delim."\" skip=\"".s:skip."\" end=\"".s:end_delim."\" contains=@rakuInterp_q,".s:end_group." contained"
    exec "syn region rakuStringQ_qww matchgroup=rakuQuote start=\"".s:start_delim."\" skip=\"".s:skip."\" end=\"".s:end_delim."\" contains=@rakuInterp_q,rakuStringSQ,rakuStringDQ".s:end_group." contained"
    exec "syn region rakuStringQ_qq matchgroup=rakuQuote start=\"".s:start_delim."\" skip=\"".s:skip."\" end=\"".s:end_delim."\" contains=@rakuInterp_qq,".s:end_group." contained"
    exec "syn region rakuStringQ_to matchgroup=rakuQuote start=\"".s:start_delim."\\z([^".s:end_delim."]\\+\\)".s:end_delim."\" end=\"^\\s*\\z1$\" contained"
    exec "syn region rakuStringQ_qto matchgroup=rakuQuote start=\"".s:start_delim."\\z([^".s:end_delim."]\\+\\)".s:end_delim."\" skip=\"".s:skip."\" end=\"^\\s*\\z1$\" contains=@rakuInterp_q,".s:end_group." contained"
    exec "syn region rakuStringQ_qqto matchgroup=rakuQuote start=\"".s:start_delim."\\z(\[^".s:end_delim."]\\+\\)".s:end_delim."\" skip=\"".s:skip."\" end=\"^\\s*\\z1$\" contains=@rakuInterp_qq,".s:end_group." contained"

    if exists("raku_embedded_pir") || exists("raku_extended_all")
        exec "syn region rakuStringQ_PIR matchgroup=rakuQuote start=\"".s:start_delim."\" skip=\"".s:skip."\" end=\"".s:end_delim."\" contains=@rakuPIR,".s:end_group." contained"
    endif
endfor
unlet s:name s:start_delim s:end_delim s:end_group s:skip s:plain_delims s:all_delims

" :key
syn match rakuOperator display ":\@1<!::\@!!\?" nextgroup=rakuKey,rakuStringAngleFixed,rakuStringAngles,rakuStringFrench
syn match rakuKey display "\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)" contained nextgroup=rakuStringAngleFixed,rakuStringAngles,rakuStringFrench

" Regexes and grammars

syn match rakuRegexName    display "\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\?" nextgroup=rakuRegexBlockCrap skipwhite skipempty contained
syn match rakuRegexBlockCrap "[^{]*" nextgroup=rakuRegexBlock skipwhite skipempty transparent contained

syn region rakuRegexBlock
    \ matchgroup=rakuNormal
    \ start="{"
    \ end="}"
    \ contained
    \ contains=@rakuRegexen,@rakuVariables

" Perl 6 regex bits

syn cluster rakuRegexen
    \ add=rakuRxMeta
    \ add=rakuRxEscape
    \ add=rakuEscCodePoint
    \ add=rakuEscHex
    \ add=rakuEscOct
    \ add=rakuEscNull
    \ add=rakuRxAnchor
    \ add=rakuRxCapture
    \ add=rakuRxGroup
    \ add=rakuRxAlternation
    \ add=rakuRxBoundary
    \ add=rakuRxAdverb
    \ add=rakuRxAdverbArg
    \ add=rakuRxStorage
    \ add=rakuRxAssertion
    \ add=rakuRxAssertGroup
    \ add=rakuRxQuoteWords
    \ add=rakuRxClosure
    \ add=rakuRxStringSQ
    \ add=rakuRxStringDQ
    \ add=rakuComment
    \ add=rakuBracketComment
    \ add=rakuMatchVarSigil

syn match rakuRxMeta        display contained ".\%([A-Za-z_\xC0-\xFF0-9]\|\s\)\@1<!"
syn match rakuRxAnchor      display contained "[$^]"
syn match rakuRxEscape      display contained "\\\S"
syn match rakuRxCapture     display contained "[()]"
syn match rakuRxAlternation display contained "|"
syn match rakuRxRange       display contained "\.\."

" misc escapes
syn match rakuEscOctOld    display "\\[1-9]\d\{1,2}" contained
syn match rakuEscNull      display "\\0\d\@!" contained
syn match rakuEscCodePoint display "\\[cC]" contained nextgroup=rakuCodePoint
syn match rakuEscHex       display "\\[xX]" contained nextgroup=rakuHexSequence
syn match rakuEscOct       display "\\o" contained nextgroup=rakuOctSequence
syn match rakuEscQQ        display "\\qq" contained nextgroup=rakuQQSequence
syn match rakuEscOpenCurly display "\\{" contained
syn match rakuEscHash      display "\\#" contained
syn match rakuEscBackSlash display "\\\\" contained

syn region rakuQQSequence
    \ matchgroup=rakuEscape
    \ start="\["
    \ skip="\[[^\]]*]"
    \ end="]"
    \ contained transparent
    \ contains=@rakuInterp_qq

syn match rakuCodePoint   display "\%(\d\+\|\S\)" contained
syn region rakuCodePoint
    \ matchgroup=rakuEscape
    \ start="\["
    \ end="]"
    \ contained

syn match rakuHexSequence display "\x\+" contained
syn region rakuHexSequence
    \ matchgroup=rakuEscape
    \ start="\["
    \ end="]"
    \ contained

syn match rakuOctSequence display "\o\+" contained
syn region rakuOctSequence
    \ matchgroup=rakuEscape
    \ start="\["
    \ end="]"
    \ contained

" $<match>, @<match>
syn region rakuMatchVarSigil
    \ matchgroup=rakuVariable
    \ start="[$@]\%(<<\@!\)\@="
    \ end=">\@1<="
    \ contains=rakuMatchVar

syn region rakuMatchVar
    \ matchgroup=rakuTwigil
    \ start="<"
    \ end=">"
    \ contained

syn region rakuRxClosure
    \ matchgroup=rakuNormal
    \ start="{"
    \ end="}"
    \ contained
    \ containedin=rakuRxClosure
    \ contains=TOP
syn region rakuRxGroup
    \ matchgroup=rakuStringSpecial2
    \ start="\["
    \ end="]"
    \ contained
    \ contains=@rakuRegexen,@rakuVariables,rakuMatchVarSigil
syn region rakuRxAssertion
    \ matchgroup=rakuStringSpecial2
    \ start="<\%(?\?\%(before\|after\)\|\%(\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)=\)\|[+?*]\)\?"
    \ end=">"
    \ contained
    \ contains=@rakuRegexen,rakuIdentifier,@rakuVariables,rakuRxCharClass,rakuRxAssertCall
syn region rakuRxAssertGroup
    \ matchgroup=rakuStringSpecial2
    \ start="<\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)=\["
    \ skip="\\\@1<!\\]"
    \ end="]"
    \ contained
syn match rakuRxAssertCall display "\%(::\|\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\)" contained nextgroup=rakuRxAssertArgs
syn region rakuRxAssertArgs
    \ start="("
    \ end=")"
    \ contained keepend
    \ contains=TOP
syn region rakuRxAssertArgs
    \ start=":"
    \ end="\ze>"
    \ contained keepend
    \ contains=TOP
syn match rakuRxBoundary display contained "\%([«»]\|<<\|>>\)"
syn region rakuRxCharClass
    \ matchgroup=rakuStringSpecial2
    \ start="\%(<[-!+?]\?\)\@2<=\["
    \ skip="\\]"
    \ end="]"
    \ contained
    \ contains=rakuRxRange,rakuRxEscape,rakuEscHex,rakuEscOct,rakuEscCodePoint,rakuEscNull
syn region rakuRxQuoteWords
    \ matchgroup=rakuStringSpecial2
    \ start="<\s"
    \ end="\s\?>"
    \ contained
syn region rakuRxAdverb
    \ start="\ze\z(:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\)"
    \ end="\z1\zs"
    \ contained keepend
    \ contains=TOP
syn region rakuRxAdverbArg
    \ start="\%(:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\)\@<=("
    \ skip="([^)]\{-})"
    \ end=")"
    \ contained
    \ keepend
    \ contains=TOP
syn region rakuRxStorage
    \ matchgroup=rakuOperator
    \ start="\%(^\s*\)\@<=:\%(my\>\|temp\>\)\@="
    \ end="$"
    \ contains=TOP
    \ contained
    \ keepend

" 'string' inside a regex
syn region rakuRxStringSQ
    \ matchgroup=rakuQuote
    \ start="'"
    \ skip="\\\@1<!\\'"
    \ end="'"
    \ contained
    \ contains=rakuEscQuote,rakuEscBackSlash

" "string" inside a regex
syn region rakuRxStringDQ
    \ matchgroup=rakuQuote
    \ start=+"+
    \ skip=+\\\@1<!\\"+
    \ end=+"+
    \ contained
    \ contains=rakuEscDoubleQuote,rakuEscBackSlash,@rakuInterp_qq

" $!, $var, $!var, $::var, $package::var $*::package::var, etc
" Thus must come after the matches for the "$" regex anchor, but before
" the match for the $ regex delimiter
syn cluster rakuVariables
    \ add=rakuVarSlash
    \ add=rakuVarExclam
    \ add=rakuVarMatch
    \ add=rakuVarNum
    \ add=rakuVariable

syn match rakuBareSigil    display "[@$%&]\%(\s*\%([,)}=]\|where\>\)\)\@="
syn match rakuVarSlash     display "\$/"
syn match rakuVarExclam    display "\$!"
syn match rakuVarMatch     display "\$¢"
syn match rakuVarNum       display "\$\d\+"
syn match rakuVariable     display "self"
syn match rakuVariable     display "[@$%&]\?[@&$%]\$*\%(::\|\%(\%([.^*?=!~]\|:\@1<!::\@!\)[A-Za-z_\xC0-\xFF]\)\|[A-Za-z_\xC0-\xFF]\)\@=" nextgroup=rakuTwigil,rakuVarName,rakuPackageScope
syn match rakuVarName      display "\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)" nextgroup=rakuPostHyperOp contained
syn match rakuClose        display "[\])]" transparent nextgroup=rakuPostHyperOp
syn match rakuPostHyperOp  display "\%(»\|>>\)" contained
syn match rakuTwigil       display "\%([.^*?=!~]\|:\@1<!::\@!\)[A-Za-z_\xC0-\xFF]\@=" nextgroup=rakuPackageScope,rakuVarName contained
syn match rakuPackageScope display "\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\?::" nextgroup=rakuPackageScope,rakuVarName contained

" Perl 6 regex regions

syn match rakuMatchStart_m    display "\.\@1<!\<\%(mm\?\|rx\)\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\)\@!" skipwhite skipempty nextgroup=rakuMatchAdverbs_m
syn match rakuMatchStart_s    display "\.\@1<!\<[sS]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\)\@!" skipwhite skipempty nextgroup=rakuMatchAdverbs_s
syn match rakuMatchStart_tr   display "\.\@1<!\<tr\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\)\@!" skipwhite skipempty nextgroup=rakuMatchAdverbs_tr
syn match rakuMatchAdverbs_m  "\%(\_s*:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\)\?\)*" contained transparent skipwhite skipempty nextgroup=rakuMatch
syn match rakuMatchAdverbs_s  "\%(\_s*:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\)\?\)*" contained transparent skipwhite skipempty nextgroup=rakuSubstitution
syn match rakuMatchAdverbs_tr "\%(\_s*:!\?\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\%(([^)]*)\)\?\)*" contained transparent skipwhite skipempty nextgroup=rakuTransliteration

" /foo/
syn region rakuMatchBare
    \ matchgroup=rakuQuote
    \ start="/\@1<!\%(\%(\_^\|[!\[,=~|&/:({]\|\^\?fff\?\^\?\|=>\|\<\%(if\|unless\|while\|when\|where\|so\)\)\s*\)\@<=/[/=]\@!"
    \ skip="\\/"
    \ end="/"
    \ contains=@rakuRegexen,rakuVariable,rakuVarExclam,rakuVarMatch,rakuVarNum

" m/foo/, m$foo$, m!foo!, etc
syn region rakuMatch
    \ matchgroup=rakuQuote
    \ start=+\z([/!$,|`"]\)+
    \ skip="\\\z1"
    \ end="\z1"
    \ contained
    \ contains=@rakuRegexen,rakuVariable,rakuVarNum

" m<foo>, m«foo», m{foo}, etc
for [s:name, s:start_delim, s:end_delim, s:end_group, s:skip] in s:bracketing_delims
    exec "syn region rakuMatch matchgroup=rakuQuote start=\"".s:start_delim."\" skip=\"".s:skip."\" end=\"".s:end_delim."\" contained keepend contains=@rakuRegexen,@rakuVariables"
endfor
unlet s:name s:start_delim s:end_delim s:end_group s:skip

" Substitutions

" s/foo//, s$foo$$, s!foo!!, etc
syn region rakuSubstitution
    \ matchgroup=rakuQuote
    \ start=+\z([/!$,|`"]\)+
    \ skip="\\\z1"
    \ end="\z1"me=e-1
    \ contained
    \ contains=@rakuRegexen,rakuVariable,rakuVarNum
    \ nextgroup=rakuReplacement

syn region rakuReplacement
    \ matchgroup=rakuQuote
    \ start="\z(.\)"
    \ skip="\\\z1"
    \ end="\z1"
    \ contained
    \ contains=@rakuInterp_qq

" s<foo><bar>, s«foo»«bar», s{foo}{bar}, etc
for [s:name, s:start_delim, s:end_delim, s:end_group, s:skip] in s:bracketing_delims
    exec "syn region rakuSubstitution matchgroup=rakuQuote start=\"".s:start_delim."\" skip=\"".s:skip."\" end=\"".s:end_delim."\" contained keepend contains=@rakuRegexen,@rakuVariables nextgroup=rakuRepl".s:name
    exec "syn region rakuRepl".s:name." matchgroup=rakuQuote start=\"".s:start_delim."\" skip=\"".s:skip."\" end=\"".s:end_delim."\" contained keepend contains=@rakuInterp_qq"
endfor
unlet s:name s:start_delim s:end_delim s:end_group s:skip

" Transliteration

" tr/foo/bar/, tr|foo|bar, etc
syn region rakuTransliteration
    \ matchgroup=rakuQuote
    \ start=+\z([/!$,|`"]\)+
    \ skip="\\\z1"
    \ end="\z1"me=e-1
    \ contained
    \ contains=rakuRxRange
    \ nextgroup=rakuTransRepl

syn region rakuTransRepl
    \ matchgroup=rakuQuote
    \ start="\z(.\)"
    \ skip="\\\z1"
    \ end="\z1"
    \ contained
    \ contains=@rakuInterp_qq,rakuRxRange

" tr<foo><bar>, tr«foo»«bar», tr{foo}{bar}, etc
for [s:name, s:start_delim, s:end_delim, s:end_group, s:skip] in s:bracketing_delims
    exec "syn region rakuTransliteration matchgroup=rakuQuote start=\"".s:start_delim."\" skip=\"".s:skip."\" end=\"".s:end_delim."\" contained keepend contains=rakuRxRange nextgroup=rakuTransRepl".s:name
    exec "syn region rakuTransRepl".s:name." matchgroup=rakuQuote start=\"".s:start_delim."\" skip=\"".s:skip."\" end=\"".s:end_delim."\" contained keepend contains=@rakuInterp_qq,rakuRxRange"
endfor
unlet s:name s:start_delim s:end_delim s:end_group s:skip s:bracketing_delims

if exists("raku_perl5_regexes") || exists("raku_extended_all")

" Perl 5 regex regions

syn cluster rakuRegexP5Base
    \ add=rakuRxP5Escape
    \ add=rakuRxP5Oct
    \ add=rakuRxP5Hex
    \ add=rakuRxP5EscMeta
    \ add=rakuRxP5CodePoint
    \ add=rakuRxP5Prop

" normal regex stuff
syn cluster rakuRegexP5
    \ add=@rakuRegexP5Base
    \ add=rakuRxP5Quantifier
    \ add=rakuRxP5Meta
    \ add=rakuRxP5QuoteMeta
    \ add=rakuRxP5ParenMod
    \ add=rakuRxP5Verb
    \ add=rakuRxP5Count
    \ add=rakuRxP5Named
    \ add=rakuRxP5ReadRef
    \ add=rakuRxP5WriteRef
    \ add=rakuRxP5CharClass
    \ add=rakuRxP5Anchor

" inside character classes
syn cluster rakuRegexP5Class
    \ add=@rakuRegexP5Base
    \ add=rakuRxP5Posix
    \ add=rakuRxP5Range

syn match rakuRxP5Escape     display contained "\\\S"
syn match rakuRxP5CodePoint  display contained "\\c\S\@=" nextgroup=rakuRxP5CPId
syn match rakuRxP5CPId       display contained "\S"
syn match rakuRxP5Oct        display contained "\\\%(\o\{1,3}\)\@=" nextgroup=rakuRxP5OctSeq
syn match rakuRxP5OctSeq     display contained "\o\{1,3}"
syn match rakuRxP5Anchor     display contained "[\^$]"
syn match rakuRxP5Hex        display contained "\\x\%({\x\+}\|\x\{1,2}\)\@=" nextgroup=rakuRxP5HexSeq
syn match rakuRxP5HexSeq     display contained "\x\{1,2}"
syn region rakuRxP5HexSeq
    \ matchgroup=rakuRxP5Escape
    \ start="{"
    \ end="}"
    \ contained
syn region rakuRxP5Named
    \ matchgroup=rakuRxP5Escape
    \ start="\%(\\N\)\@2<={"
    \ end="}"
    \ contained
syn match rakuRxP5Quantifier display contained "\%([+*]\|(\@1<!?\)"
syn match rakuRxP5ReadRef    display contained "\\[1-9]\d\@!"
syn match rakuRxP5ReadRef    display contained "\[A-Za-z_\xC0-\xFF0-9]<\@=" nextgroup=rakuRxP5ReadRefId
syn region rakuRxP5ReadRefId
    \ matchgroup=rakuRxP5Escape
    \ start="<"
    \ end=">"
    \ contained
syn match rakuRxP5WriteRef   display contained "\\g\%(\d\|{\)\@=" nextgroup=rakuRxP5WriteRefId
syn match rakuRxP5WriteRefId display contained "\d\+"
syn region rakuRxP5WriteRefId
    \ matchgroup=rakuRxP5Escape
    \ start="{"
    \ end="}"
    \ contained
syn match rakuRxP5Prop       display contained "\\[pP]\%(\a\|{\)\@=" nextgroup=rakuRxP5PropId
syn match rakuRxP5PropId     display contained "\a"
syn region rakuRxP5PropId
    \ matchgroup=rakuRxP5Escape
    \ start="{"
    \ end="}"
    \ contained
syn match rakuRxP5Meta       display contained "[(|).]"
syn match rakuRxP5ParenMod   display contained "(\@1<=?\@=" nextgroup=rakuRxP5Mod,rakuRxP5ModName,rakuRxP5Code
syn match rakuRxP5Mod        display contained "?\%(<\?=\|<\?!\|[#:|]\)"
syn match rakuRxP5Mod        display contained "?-\?[impsx]\+"
syn match rakuRxP5Mod        display contained "?\%([-+]\?\d\+\|R\)"
syn match rakuRxP5Mod        display contained "?(DEFINE)"
syn match rakuRxP5Mod        display contained "?\%(&\|P[>=]\)" nextgroup=rakuRxP5ModDef
syn match rakuRxP5ModDef     display contained "\h\w*"
syn region rakuRxP5ModName
    \ matchgroup=rakuStringSpecial
    \ start="?'"
    \ end="'"
    \ contained
syn region rakuRxP5ModName
    \ matchgroup=rakuStringSpecial
    \ start="?P\?<"
    \ end=">"
    \ contained
syn region rakuRxP5Code
    \ matchgroup=rakuStringSpecial
    \ start="??\?{"
    \ end="})\@="
    \ contained
    \ contains=TOP
syn match rakuRxP5EscMeta    display contained "\\[?*.{}()[\]|\^$]"
syn match rakuRxP5Count      display contained "\%({\d\+\%(,\%(\d\+\)\?\)\?}\)\@=" nextgroup=rakuRxP5CountId
syn region rakuRxP5CountId
    \ matchgroup=rakuRxP5Escape
    \ start="{"
    \ end="}"
    \ contained
syn match rakuRxP5Verb       display contained "(\@1<=\*\%(\%(PRUNE\|SKIP\|THEN\)\%(:[^)]*\)\?\|\%(MARK\|\):[^)]*\|COMMIT\|F\%(AIL\)\?\|ACCEPT\)"
syn region rakuRxP5QuoteMeta
    \ matchgroup=rakuRxP5Escape
    \ start="\\Q"
    \ end="\\E"
    \ contained
    \ contains=@rakuVariables,rakuEscBackSlash
syn region rakuRxP5CharClass
    \ matchgroup=rakuStringSpecial
    \ start="\[\^\?"
    \ skip="\\]"
    \ end="]"
    \ contained
    \ contains=@rakuRegexP5Class
syn region rakuRxP5Posix
    \ matchgroup=rakuRxP5Escape
    \ start="\[:"
    \ end=":]"
    \ contained
syn match rakuRxP5Range      display contained "-"

" m:P5//
syn region rakuMatch
    \ matchgroup=rakuQuote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@2<!\<m\s*:P\%(erl\)\?5\s*\)\@<=/"
    \ skip="\\/"
    \ end="/"
    \ contains=@rakuRegexP5,rakuVariable,rakuVarExclam,rakuVarMatch,rakuVarNum

" m:P5!!
syn region rakuMatch
    \ matchgroup=rakuQuote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@2<!\<m\s*:P\%(erl\)\?5\s*\)\@<=!"
    \ skip="\\!"
    \ end="!"
    \ contains=@rakuRegexP5,rakuVariable,rakuVarSlash,rakuVarMatch,rakuVarNum

" m:P5$$, m:P5||, etc
syn region rakuMatch
    \ matchgroup=rakuQuote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@2<!\<m\s*:P\%(erl\)\?5\s*\)\@<=\z([\"'`|,$]\)"
    \ skip="\\\z1"
    \ end="\z1"
    \ contains=@rakuRegexP5,@rakuVariables

" m:P5 ()
syn region rakuMatch
    \ matchgroup=rakuQuote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@2<!\<m\s*:P\%(erl\)\?5\s\+\)\@<=()\@!"
    \ skip="\\)"
    \ end=")"
    \ contains=@rakuRegexP5,@rakuVariables

" m:P5[]
syn region rakuMatch
    \ matchgroup=rakuQuote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@2<!\<m\s*:P\%(erl\)\?5\s*\)\@<=[]\@!"
    \ skip="\\]"
    \ end="]"
    \ contains=@rakuRegexP5,@rakuVariables

" m:P5{}
syn region rakuMatch
    \ matchgroup=rakuQuote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@2<!\<m\s*:P\%(erl\)\?5\s*\)\@<={}\@!"
    \ skip="\\}"
    \ end="}"
    \ contains=@rakuRegexP5,rakuVariables

" m:P5<>
syn region rakuMatch
    \ matchgroup=rakuQuote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@2<!\<m\s*:P\%(erl\)\?5\s*\)\@<=<>\@!"
    \ skip="\\>"
    \ end=">"
    \ contains=@rakuRegexP5,rakuVariables

" m:P5«»
syn region rakuMatch
    \ matchgroup=rakuQuote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@2<!\<m\s*:P\%(erl\)\?5\s*\)\@<=«»\@!"
    \ skip="\\»"
    \ end="»"
    \ contains=@rakuRegexP5,rakuVariables

endif

" Comments

syn match rakuAttention display "\<\%(ACHTUNG\|ATTN\|ATTENTION\|FIXME\|NB\|TODO\|TBD\|WTF\|XXX\|NOTE\)" contained

" normal end-of-line comment
syn match rakuComment display "#.*" contains=rakuAttention

" Multiline comments. Arbitrary numbers of opening brackets are allowed,
" but we only define regions for 1 to 3
syn region rakuBracketComment
    \ start="#[`|=]("
    \ skip="([^)]*)"
    \ end=")"
    \ contains=rakuAttention,rakuBracketComment
syn region rakuBracketComment
    \ start="#[`|=]\["
    \ skip="\[[^\]]*]"
    \ end="]"
    \ contains=rakuAttention,rakuBracketComment
syn region rakuBracketComment
    \ start="#[`|=]{"
    \ skip="{[^}]*}"
    \ end="}"
    \ contains=rakuAttention,rakuBracketComment
syn region rakuBracketComment
    \ start="#[`|=]<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contains=rakuAttention,rakuBracketComment
syn region rakuBracketComment
    \ start="#[`|=]«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contains=rakuAttention,rakuBracketComment

" Comments with double and triple delimiters
syn region rakuBracketComment
    \ matchgroup=rakuBracketComment
    \ start="#[`|=](("
    \ skip="((\%([^)\|))\@!]\)*))"
    \ end="))"
    \ contains=rakuAttention,rakuBracketComment
syn region rakuBracketComment
    \ matchgroup=rakuBracketComment
    \ start="#[`|=]((("
    \ skip="(((\%([^)]\|)\%())\)\@!\)*)))"
    \ end=")))"
    \ contains=rakuAttention,rakuBracketComment

syn region rakuBracketComment
    \ matchgroup=rakuBracketComment
    \ start="#[`|=]\[\["
    \ skip="\[\[\%([^\]]\|]]\@!\)*]]"
    \ end="]]"
    \ contains=rakuAttention,rakuBracketComment
syn region rakuBracketComment
    \ matchgroup=rakuBracketComment
    \ start="#[`|=]\[\[\["
    \ skip="\[\[\[\%([^\]]\|]\%(]]\)\@!\)*]]]"
    \ end="]]]"
    \ contains=rakuAttention,rakuBracketComment

syn region rakuBracketComment
    \ matchgroup=rakuBracketComment
    \ start="#[`|=]{{"
    \ skip="{{\%([^}]\|}}\@!\)*}}"
    \ end="}}"
    \ contains=rakuAttention,rakuBracketComment
syn region rakuBracketComment
    \ matchgroup=rakuBracketComment
    \ start="#[`|=]{{{"
    \ skip="{{{\%([^}]\|}\%(}}\)\@!\)*}}}"
    \ end="}}}"
    \ contains=rakuAttention,rakuBracketComment

syn region rakuBracketComment
    \ matchgroup=rakuBracketComment
    \ start="#[`|=]<<"
    \ skip="<<\%([^>]\|>>\@!\)*>>"
    \ end=">>"
    \ contains=rakuAttention,rakuBracketComment
syn region rakuBracketComment
    \ matchgroup=rakuBracketComment
    \ start="#[`|=]<<<"
    \ skip="<<<\%([^>]\|>\%(>>\)\@!\)*>>>"
    \ end=">>>"
    \ contains=rakuAttention,rakuBracketComment

syn region rakuBracketComment
    \ matchgroup=rakuBracketComment
    \ start="#[`|=]««"
    \ skip="««\%([^»]\|»»\@!\)*»»"
    \ end="»»"
    \ contains=rakuAttention,rakuBracketComment
syn region rakuBracketComment
    \ matchgroup=rakuBracketComment
    \ start="#[`|=]«««"
    \ skip="«««\%([^»]\|»\%(»»\)\@!\)*»»»"
    \ end="»»»"
    \ contains=rakuAttention,rakuBracketComment

syn match rakuShebang display "\%^#!.*"

" => autoquoting
syn match rakuStringAuto   display "\.\@1<!\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\ze\%(p5\)\@2<![RSXZ]\@1<!=>"
syn match rakuStringAuto   display "\.\@1<!\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\ze\s\+=>"
syn match rakuStringAuto   display "\.\@1<!\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)p5\ze=>"

" Pod

" Abbreviated blocks (implicit code forbidden)
syn region rakuPodAbbrRegion
    \ matchgroup=rakuPodPrefix
    \ start="^\s*\zs=\ze\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contains=rakuPodAbbrNoCodeType
    \ keepend

syn region rakuPodAbbrNoCodeType
    \ matchgroup=rakuPodType
    \ start="\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contained
    \ contains=rakuPodName,rakuPodAbbrNoCode

syn match rakuPodName contained ".\+" contains=@rakuPodFormat
syn match rakuPodComment contained ".\+"

syn region rakuPodAbbrNoCode
    \ start="^"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contained
    \ contains=@rakuPodFormat

" Abbreviated blocks (everything is code)
syn region rakuPodAbbrRegion
    \ matchgroup=rakuPodPrefix
    \ start="^\s*\zs=\zecode\>"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contains=rakuPodAbbrCodeType
    \ keepend

syn region rakuPodAbbrCodeType
    \ matchgroup=rakuPodType
    \ start="\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contained
    \ contains=rakuPodName,rakuPodAbbrCode

syn region rakuPodAbbrCode
    \ start="^"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contained

" Abbreviated blocks (everything is a comment)
syn region rakuPodAbbrRegion
    \ matchgroup=rakuPodPrefix
    \ start="^=\zecomment\>"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contains=rakuPodAbbrCommentType
    \ keepend

syn region rakuPodAbbrCommentType
    \ matchgroup=rakuPodType
    \ start="\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contained
    \ contains=rakuPodComment,rakuPodAbbrNoCode

" Abbreviated blocks (implicit code allowed)
syn region rakuPodAbbrRegion
    \ matchgroup=rakuPodPrefix
    \ start="^=\ze\%(pod\|item\|nested\|\u\+\)\>"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contains=rakuPodAbbrType
    \ keepend

syn region rakuPodAbbrType
    \ matchgroup=rakuPodType
    \ start="\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contained
    \ contains=rakuPodName,rakuPodAbbr

syn region rakuPodAbbr
    \ start="^"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contained
    \ contains=@rakuPodFormat,rakuPodImplicitCode

" Abbreviated block to end-of-file
syn region rakuPodAbbrRegion
    \ matchgroup=rakuPodPrefix
    \ start="^=\zeEND\>"
    \ end="\%$"
    \ contains=rakuPodAbbrEOFType
    \ keepend

syn region rakuPodAbbrEOFType
    \ matchgroup=rakuPodType
    \ start="\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="\%$"
    \ contained
    \ contains=rakuPodName,rakuPodAbbrEOF

syn region rakuPodAbbrEOF
    \ start="^"
    \ end="\%$"
    \ contained
    \ contains=@rakuPodNestedBlocks,@rakuPodFormat,rakuPodImplicitCode

" Directives
syn region rakuPodDirectRegion
    \ matchgroup=rakuPodPrefix
    \ start="^=\%(config\|use\)\>"
    \ end="^\ze\%([^=]\|=[A-Za-z_\xC0-\xFF]\|\s*$\)"
    \ contains=rakuPodDirectArgRegion
    \ keepend

syn region rakuPodDirectArgRegion
    \ matchgroup=rakuPodType
    \ start="\S\+"
    \ end="^\ze\%([^=]\|=[A-Za-z_\xC0-\xFF]\|\s*$\)"
    \ contained
    \ contains=rakuPodDirectConfigRegion

syn region rakuPodDirectConfigRegion
    \ start=""
    \ end="^\ze\%([^=]\|=[A-Za-z_\xC0-\xFF]\|\s*$\)"
    \ contained
    \ contains=@rakuPodConfig

" =encoding is a special directive
syn region rakuPodDirectRegion
    \ matchgroup=rakuPodPrefix
    \ start="^=encoding\>"
    \ end="^\ze\%([^=]\|=[A-Za-z_\xC0-\xFF]\|\s*$\)"
    \ contains=rakuPodEncodingArgRegion
    \ keepend

syn region rakuPodEncodingArgRegion
    \ matchgroup=rakuPodName
    \ start="\S\+"
    \ end="^\ze\%([^=]\|=[A-Za-z_\xC0-\xFF]\|\s*$\)"
    \ contained

" Paragraph blocks (implicit code forbidden)
syn region rakuPodParaRegion
    \ matchgroup=rakuPodPrefix
    \ start="^\s*\zs=for\>"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contains=rakuPodParaNoCodeTypeRegion
    \ keepend extend

syn region rakuPodParaNoCodeTypeRegion
    \ matchgroup=rakuPodType
    \ start="\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="^\s*\zs\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contained
    \ contains=rakuPodParaNoCode,rakuPodParaConfigRegion

syn region rakuPodParaConfigRegion
    \ start=""
    \ end="^\ze\%([^=]\|=[A-Za-z_\xC0-\xFF]\@1<!\)"
    \ contained
    \ contains=@rakuPodConfig

syn region rakuPodParaNoCode
    \ start="^[^=]"
    \ end="^\s*\zs\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contained
    \ contains=@rakuPodFormat

" Paragraph blocks (everything is code)
syn region rakuPodParaRegion
    \ matchgroup=rakuPodPrefix
    \ start="^\s*\zs=for\>\ze\s*code\>"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contains=rakuPodParaCodeTypeRegion
    \ keepend extend

syn region rakuPodParaCodeTypeRegion
    \ matchgroup=rakuPodType
    \ start="\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="^\s*\zs\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contained
    \ contains=rakuPodParaCode,rakuPodParaConfigRegion

syn region rakuPodParaCode
    \ start="^[^=]"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contained

" Paragraph blocks (implicit code allowed)
syn region rakuPodParaRegion
    \ matchgroup=rakuPodPrefix
    \ start="^\s*\zs=for\>\ze\s*\%(pod\|item\|nested\|\u\+\)\>"
    \ end="^\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contains=rakuPodParaTypeRegion
    \ keepend extend

syn region rakuPodParaTypeRegion
    \ matchgroup=rakuPodType
    \ start="\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="^\s*\zs\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contained
    \ contains=rakuPodPara,rakuPodParaConfigRegion

syn region rakuPodPara
    \ start="^[^=]"
    \ end="^\s*\zs\ze\%(\s*$\|=[A-Za-z_\xC0-\xFF]\)"
    \ contained
    \ contains=@rakuPodFormat,rakuPodImplicitCode

" Paragraph block to end-of-file
syn region rakuPodParaRegion
    \ matchgroup=rakuPodPrefix
    \ start="^=for\>\ze\s\+END\>"
    \ end="\%$"
    \ contains=rakuPodParaEOFTypeRegion
    \ keepend extend

syn region rakuPodParaEOFTypeRegion
    \ matchgroup=rakuPodType
    \ start="\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="\%$"
    \ contained
    \ contains=rakuPodParaEOF,rakuPodParaConfigRegion

syn region rakuPodParaEOF
    \ start="^[^=]"
    \ end="\%$"
    \ contained
    \ contains=@rakuPodNestedBlocks,@rakuPodFormat,rakuPodImplicitCode

" Delimited blocks (implicit code forbidden)
syn region rakuPodDelimRegion
    \ matchgroup=rakuPodPrefix
    \ start="^\z(\s*\)\zs=begin\>"
    \ end="^\z1\zs=end\>"
    \ contains=rakuPodDelimNoCodeTypeRegion
    \ keepend extend skipwhite
    \ nextgroup=rakuPodType

syn region rakuPodDelimNoCodeTypeRegion
    \ matchgroup=rakuPodType
    \ start="\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="^\s*\zs\ze=end\>"
    \ contained
    \ contains=rakuPodDelimNoCode,rakuPodDelimConfigRegion

syn region rakuPodDelimConfigRegion
    \ start=""
    \ end="^\s*\zs\ze\%([^=]\|=[A-Za-z_\xC0-\xFF]\|\s*$\)"
    \ contained
    \ contains=@rakuPodConfig

syn region rakuPodDelimNoCode
    \ start="^"
    \ end="^\s*\zs\ze=end\>"
    \ contained
    \ contains=@rakuPodNestedBlocks,@rakuPodFormat

" Delimited blocks (everything is code)
syn region rakuPodDelimRegion
    \ matchgroup=rakuPodPrefix
    \ start="^\z(\s*\)\zs=begin\>\ze\s*code\>"
    \ end="^\z1\zs=end\>"
    \ contains=rakuPodDelimCodeTypeRegion
    \ keepend extend skipwhite
    \ nextgroup=rakuPodType

syn region rakuPodDelimCodeTypeRegion
    \ matchgroup=rakuPodType
    \ start="\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="^\s*\zs\ze=end\>"
    \ contained
    \ contains=rakuPodDelimCode,rakuPodDelimConfigRegion

syn region rakuPodDelimCode
    \ start="^"
    \ end="^\s*\zs\ze=end\>"
    \ contained
    \ contains=@rakuPodNestedBlocks

" Delimited blocks (implicit code allowed)
syn region rakuPodDelimRegion
    \ matchgroup=rakuPodPrefix
    \ start="^\z(\s*\)\zs=begin\>\ze\s*\%(pod\|item\|nested\|\u\+\)\>"
    \ end="^\z1\zs=end\>"
    \ contains=rakuPodDelimTypeRegion
    \ keepend extend skipwhite
    \ nextgroup=rakuPodType

syn region rakuPodDelimTypeRegion
    \ matchgroup=rakuPodType
    \ start="\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="^\s*\zs\ze=end\>"
    \ contained
    \ contains=rakuPodDelim,rakuPodDelimConfigRegion

syn region rakuPodDelim
    \ start="^"
    \ end="^\s*\zs\ze=end\>"
    \ contained
    \ contains=@rakuPodNestedBlocks,@rakuPodFormat,rakuPodImplicitCode

" Delimited block to end-of-file
syn region rakuPodDelimRegion
    \ matchgroup=rakuPodPrefix
    \ start="^=begin\>\ze\s\+END\>"
    \ end="\%$"
    \ extend
    \ contains=rakuPodDelimEOFTypeRegion

syn region rakuPodDelimEOFTypeRegion
    \ matchgroup=rakuPodType
    \ start="\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"
    \ end="\%$"
    \ contained
    \ contains=rakuPodDelimEOF,rakuPodDelimConfigRegion

syn region rakuPodDelimEOF
    \ start="^"
    \ end="\%$"
    \ contained
    \ contains=@rakuPodNestedBlocks,@rakuPodFormat,rakuPodImplicitCode

syn cluster rakuPodConfig
    \ add=rakuPodConfigOperator
    \ add=rakuPodExtraConfig
    \ add=rakuStringAuto
    \ add=rakuPodAutoQuote
    \ add=rakuStringSQ

syn region rakuPodParens
    \ start="("
    \ end=")"
    \ contained
    \ contains=rakuNumber,rakuStringSQ

syn match rakuPodAutoQuote      display contained "=>"
syn match rakuPodConfigOperator display contained ":!\?" nextgroup=rakuPodConfigOption
syn match rakuPodConfigOption   display contained "[^[:space:](<]\+" nextgroup=rakuPodParens,rakuStringAngle
syn match rakuPodExtraConfig    display contained "^="
syn match rakuPodVerticalBar    display contained "|"
syn match rakuPodColon          display contained ":"
syn match rakuPodSemicolon      display contained ";"
syn match rakuPodComma          display contained ","
syn match rakuPodImplicitCode   display contained "^\s.*"
syn match rakuPodType           display contained "\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)"

" These may appear inside delimited blocks
syn cluster rakuPodNestedBlocks
    \ add=rakuPodAbbrRegion
    \ add=rakuPodDirectRegion
    \ add=rakuPodParaRegion
    \ add=rakuPodDelimRegion

" Pod formatting codes

syn cluster rakuPodFormat
    \ add=rakuPodFormatOne
    \ add=rakuPodFormatTwo
    \ add=rakuPodFormatThree
    \ add=rakuPodFormatFrench

" Balanced angles found inside formatting codes. Ensures proper nesting.

syn region rakuPodFormatAnglesOne
    \ matchgroup=rakuPodFormat
    \ start="<"
    \ skip="<[^>]*>"
    \ end=">"
    \ transparent contained
    \ contains=rakuPodFormatAnglesFrench,rakuPodFormatAnglesOne

syn region rakuPodFormatAnglesTwo
    \ matchgroup=rakuPodFormat
    \ start="<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ transparent contained
    \ contains=rakuPodFormatAnglesFrench,rakuPodFormatAnglesOne,rakuPodFormatAnglesTwo

syn region rakuPodFormatAnglesThree
    \ matchgroup=rakuPodFormat
    \ start="<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ transparent contained
    \ contains=rakuPodFormatAnglesFrench,rakuPodFormatAnglesOne,rakuPodFormatAnglesTwo,rakuPodFormatAnglesThree

syn region rakuPodFormatAnglesFrench
    \ matchgroup=rakuPodFormat
    \ start="«"
    \ skip="«[^»]*»"
    \ end="»"
    \ transparent contained
    \ contains=rakuPodFormatAnglesFrench,rakuPodFormatAnglesOne,rakuPodFormatAnglesTwo,rakuPodFormatAnglesThree

" All formatting codes

syn region rakuPodFormatOne
    \ matchgroup=rakuPodFormatCode
    \ start="\u<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=rakuPodFormatAnglesOne,rakuPodFormatFrench,rakuPodFormatOne

syn region rakuPodFormatTwo
    \ matchgroup=rakuPodFormatCode
    \ start="\u<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=rakuPodFormatAnglesTwo,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo

syn region rakuPodFormatThree
    \ matchgroup=rakuPodFormatCode
    \ start="\u<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=rakuPodFormatAnglesThree,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodFormatThree

syn region rakuPodFormatFrench
    \ matchgroup=rakuPodFormatCode
    \ start="\u«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=rakuPodFormatAnglesFrench,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodFormatThree

" C<> and V<> don't allow nested formatting formatting codes

syn region rakuPodFormatOne
    \ matchgroup=rakuPodFormatCode
    \ start="[CV]<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=rakuPodFormatAnglesOne

syn region rakuPodFormatTwo
    \ matchgroup=rakuPodFormatCode
    \ start="[CV]<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=rakuPodFormatAnglesTwo

syn region rakuPodFormatThree
    \ matchgroup=rakuPodFormatCode
    \ start="[CV]<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=rakuPodFormatAnglesThree

syn region rakuPodFormatFrench
    \ matchgroup=rakuPodFormatCode
    \ start="[CV]«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=rakuPodFormatAnglesFrench

" L<> can have a "|" separator

syn region rakuPodFormatOne
    \ matchgroup=rakuPodFormatCode
    \ start="L<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=rakuPodFormatAnglesOne,rakuPodFormatFrench,rakuPodFormatOne,rakuPodVerticalBar

syn region rakuPodFormatTwo
    \ matchgroup=rakuPodFormatCode
    \ start="L<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=rakuPodFormatAnglesTwo,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodVerticalBar

syn region rakuPodFormatThree
    \ matchgroup=rakuPodFormatCode
    \ start="L<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=rakuPodFormatAnglesThree,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodFormatThree,rakuPodVerticalBar

syn region rakuPodFormatFrench
    \ matchgroup=rakuPodFormatCode
    \ start="L«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=rakuPodFormatAnglesFrench,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodFormatThree,rakuPodVerticalBar

" E<> can have a ";" separator

syn region rakuPodFormatOne
    \ matchgroup=rakuPodFormatCode
    \ start="E<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=rakuPodFormatAnglesOne,rakuPodFormatFrench,rakuPodFormatOne,rakuPodSemiColon

syn region rakuPodFormatTwo
    \ matchgroup=rakuPodFormatCode
    \ start="E<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=rakuPodFormatAnglesTwo,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodSemiColon

syn region rakuPodFormatThree
    \ matchgroup=rakuPodFormatCode
    \ start="E<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=rakuPodFormatAnglesThree,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodFormatThree,rakuPodSemiColon

syn region rakuPodFormatFrench
    \ matchgroup=rakuPodFormatCode
    \ start="E«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=rakuPodFormatAnglesFrench,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodFormatThree,rakuPodSemiColon

" M<> can have a ":" separator

syn region rakuPodFormatOne
    \ matchgroup=rakuPodFormatCode
    \ start="M<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=rakuPodFormatAnglesOne,rakuPodFormatFrench,rakuPodFormatOne,rakuPodColon

syn region rakuPodFormatTwo
    \ matchgroup=rakuPodFormatCode
    \ start="M<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=rakuPodFormatAnglesTwo,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodColon

syn region rakuPodFormatThree
    \ matchgroup=rakuPodFormatCode
    \ start="M<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=rakuPodFormatAnglesThree,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodFormatThree,rakuPodColon

syn region rakuPodFormatFrench
    \ matchgroup=rakuPodFormatCode
    \ start="M«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=rakuPodFormatAnglesFrench,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodFormatThree,rakuPodColon

" D<> can have "|" and ";" separators

syn region rakuPodFormatOne
    \ matchgroup=rakuPodFormatCode
    \ start="D<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=rakuPodFormatAnglesOne,rakuPodFormatFrench,rakuPodFormatOne,rakuPodVerticalBar,rakuPodSemiColon

syn region rakuPodFormatTwo
    \ matchgroup=rakuPodFormatCode
    \ start="D<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=rakuPodFormatAngleTwo,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodVerticalBar,rakuPodSemiColon

syn region rakuPodFormatThree
    \ matchgroup=rakuPodFormatCode
    \ start="D<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=rakuPodFormatAnglesThree,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodFormatThree,rakuPodVerticalBar,rakuPodSemiColon

syn region rakuPodFormatFrench
    \ matchgroup=rakuPodFormatCode
    \ start="D«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=rakuPodFormatAnglesFrench,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodFormatThree,rakuPodVerticalBar,rakuPodSemiColon

" X<> can have "|", "," and ";" separators

syn region rakuPodFormatOne
    \ matchgroup=rakuPodFormatCode
    \ start="X<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=rakuPodFormatAnglesOne,rakuPodFormatFrench,rakuPodFormatOne,rakuPodVerticalBar,rakuPodSemiColon,rakuPodComma

syn region rakuPodFormatTwo
    \ matchgroup=rakuPodFormatCode
    \ start="X<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=rakuPodFormatAnglesTwo,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodVerticalBar,rakuPodSemiColon,rakuPodComma

syn region rakuPodFormatThree
    \ matchgroup=rakuPodFormatCode
    \ start="X<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=rakuPodFormatAnglesThree,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodFormatThree,rakuPodVerticalBar,rakuPodSemiColon,rakuPodComma

syn region rakuPodFormatFrench
    \ matchgroup=rakuPodFormatCode
    \ start="X«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=rakuPodFormatAnglesFrench,rakuPodFormatFrench,rakuPodFormatOne,rakuPodFormatTwo,rakuPodFormatThree,rakuPodVerticalBar,rakuPodSemiColon,rakuPodComma

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_raku_syntax_inits")
    if version < 508
        let did_raku_syntax_inits = 1
        command -nargs=+ HiLink hi link <args>
    else
        command -nargs=+ HiLink hi def link <args>
    endif

    HiLink rakuEscOctOld        rakuError
    HiLink rakuPackageTwigil    rakuTwigil
    HiLink rakuStringAngle      rakuString
    HiLink rakuStringAngleFixed rakuString
    HiLink rakuStringFrench     rakuString
    HiLink rakuStringAngles     rakuString
    HiLink rakuStringSQ         rakuString
    HiLink rakuStringDQ         rakuString
    HiLink rakuStringQ          rakuString
    HiLink rakuStringQ_q        rakuString
    HiLink rakuStringQ_qww      rakuString
    HiLink rakuStringQ_qq       rakuString
    HiLink rakuStringQ_to       rakuString
    HiLink rakuStringQ_qto      rakuString
    HiLink rakuStringQ_qqto     rakuString
    HiLink rakuRxStringSQ       rakuString
    HiLink rakuRxStringDQ       rakuString
    HiLink rakuReplacement      rakuString
    HiLink rakuReplCurly        rakuString
    HiLink rakuReplAngle        rakuString
    HiLink rakuReplFrench       rakuString
    HiLink rakuReplBracket      rakuString
    HiLink rakuReplParen        rakuString
    HiLink rakuTransliteration  rakuString
    HiLink rakuTransRepl        rakuString
    HiLink rakuTransReplCurly   rakuString
    HiLink rakuTransReplAngle   rakuString
    HiLink rakuTransReplFrench  rakuString
    HiLink rakuTransReplBracket rakuString
    HiLink rakuTransReplParen   rakuString
    HiLink rakuStringAuto       rakuString
    HiLink rakuKey              rakuString
    HiLink rakuMatch            rakuString
    HiLink rakuSubstitution     rakuString
    HiLink rakuMatchBare        rakuString
    HiLink rakuRegexBlock       rakuString
    HiLink rakuRxP5CharClass    rakuString
    HiLink rakuRxP5QuoteMeta    rakuString
    HiLink rakuRxCharClass      rakuString
    HiLink rakuRxQuoteWords     rakuString
    HiLink rakuReduceOp         rakuOperator
    HiLink rakuSetOp            rakuOperator
    HiLink rakuRSXZOp           rakuOperator
    HiLink rakuHyperOp          rakuOperator
    HiLink rakuPostHyperOp      rakuOperator
    HiLink rakuQuoteQ           rakuQuote
    HiLink rakuQuoteQ_q         rakuQuote
    HiLink rakuQuoteQ_qww       rakuQuote
    HiLink rakuQuoteQ_qq        rakuQuote
    HiLink rakuQuoteQ_to        rakuQuote
    HiLink rakuQuoteQ_qto       rakuQuote
    HiLink rakuQuoteQ_qqto      rakuQuote
    HiLink rakuQuoteQ_PIR       rakuQuote
    HiLink rakuMatchStart_m     rakuQuote
    HiLink rakuMatchStart_s     rakuQuote
    HiLink rakuMatchStart_tr    rakuQuote
    HiLink rakuBareSigil        rakuVariable
    HiLink rakuRxRange          rakuStringSpecial
    HiLink rakuRxAnchor         rakuStringSpecial
    HiLink rakuRxBoundary       rakuStringSpecial
    HiLink rakuRxP5Anchor       rakuStringSpecial
    HiLink rakuCodePoint        rakuStringSpecial
    HiLink rakuRxMeta           rakuStringSpecial
    HiLink rakuRxP5Range        rakuStringSpecial
    HiLink rakuRxP5CPId         rakuStringSpecial
    HiLink rakuRxP5Posix        rakuStringSpecial
    HiLink rakuRxP5Mod          rakuStringSpecial
    HiLink rakuRxP5HexSeq       rakuStringSpecial
    HiLink rakuRxP5OctSeq       rakuStringSpecial
    HiLink rakuRxP5WriteRefId   rakuStringSpecial
    HiLink rakuHexSequence      rakuStringSpecial
    HiLink rakuOctSequence      rakuStringSpecial
    HiLink rakuRxP5Named        rakuStringSpecial
    HiLink rakuRxP5PropId       rakuStringSpecial
    HiLink rakuRxP5Quantifier   rakuStringSpecial
    HiLink rakuRxP5CountId      rakuStringSpecial
    HiLink rakuRxP5Verb         rakuStringSpecial
    HiLink rakuRxAssertGroup    rakuStringSpecial2
    HiLink rakuEscape           rakuStringSpecial2
    HiLink rakuEscNull          rakuStringSpecial2
    HiLink rakuEscHash          rakuStringSpecial2
    HiLink rakuEscQQ            rakuStringSpecial2
    HiLink rakuEscQuote         rakuStringSpecial2
    HiLink rakuEscDoubleQuote   rakuStringSpecial2
    HiLink rakuEscBackTick      rakuStringSpecial2
    HiLink rakuEscForwardSlash  rakuStringSpecial2
    HiLink rakuEscVerticalBar   rakuStringSpecial2
    HiLink rakuEscExclamation   rakuStringSpecial2
    HiLink rakuEscDollar        rakuStringSpecial2
    HiLink rakuEscOpenCurly     rakuStringSpecial2
    HiLink rakuEscCloseCurly    rakuStringSpecial2
    HiLink rakuEscCloseBracket  rakuStringSpecial2
    HiLink rakuEscCloseAngle    rakuStringSpecial2
    HiLink rakuEscCloseFrench   rakuStringSpecial2
    HiLink rakuEscBackSlash     rakuStringSpecial2
    HiLink rakuEscCodePoint     rakuStringSpecial2
    HiLink rakuEscOct           rakuStringSpecial2
    HiLink rakuEscHex           rakuStringSpecial2
    HiLink rakuRxEscape         rakuStringSpecial2
    HiLink rakuRxCapture        rakuStringSpecial2
    HiLink rakuRxAlternation    rakuStringSpecial2
    HiLink rakuRxP5             rakuStringSpecial2
    HiLink rakuRxP5ReadRef      rakuStringSpecial2
    HiLink rakuRxP5Oct          rakuStringSpecial2
    HiLink rakuRxP5Hex          rakuStringSpecial2
    HiLink rakuRxP5EscMeta      rakuStringSpecial2
    HiLink rakuRxP5Meta         rakuStringSpecial2
    HiLink rakuRxP5Escape       rakuStringSpecial2
    HiLink rakuRxP5CodePoint    rakuStringSpecial2
    HiLink rakuRxP5WriteRef     rakuStringSpecial2
    HiLink rakuRxP5Prop         rakuStringSpecial2

    HiLink rakuProperty       Tag
    HiLink rakuAttention      Todo
    HiLink rakuType           Type
    HiLink rakuError          Error
    HiLink rakuBlockLabel     Label
    HiLink rakuNormal         Normal
    HiLink rakuIdentifier     Normal
    HiLink rakuPackage        Normal
    HiLink rakuPackageScope   Normal
    HiLink rakuNumber         Number
    HiLink rakuOctNumber      Number
    HiLink rakuBinNumber      Number
    HiLink rakuHexNumber      Number
    HiLink rakuDecNumber      Number
    HiLink rakuString         String
    HiLink rakuRepeat         Repeat
    HiLink rakuPragma         Keyword
    HiLink rakuPreDeclare     Keyword
    HiLink rakuDeclare        Keyword
    HiLink rakuDeclareRegex   Keyword
    HiLink rakuVarStorage     Special
    HiLink rakuFlowControl    Special
    HiLink rakuOctBase        Special
    HiLink rakuBinBase        Special
    HiLink rakuHexBase        Special
    HiLink rakuDecBase        Special
    HiLink rakuTwigil         Special
    HiLink rakuStringSpecial2 Special
    HiLink rakuVersion        Special
    HiLink rakuComment        Comment
    HiLink rakuBracketComment Comment
    HiLink rakuInclude        Include
    HiLink rakuShebang        PreProc
    HiLink rakuClosureTrait   PreProc
    HiLink rakuOperator       Operator
    HiLink rakuContext        Operator
    HiLink rakuQuote          Delimiter
    HiLink rakuTypeConstraint PreCondit
    HiLink rakuException      Exception
    HiLink rakuVariable       Identifier
    HiLink rakuVarSlash       Identifier
    HiLink rakuVarNum         Identifier
    HiLink rakuVarExclam      Identifier
    HiLink rakuVarMatch       Identifier
    HiLink rakuVarName        Identifier
    HiLink rakuMatchVar       Identifier
    HiLink rakuRxP5ReadRefId  Identifier
    HiLink rakuRxP5ModDef     Identifier
    HiLink rakuRxP5ModName    Identifier
    HiLink rakuConditional    Conditional
    HiLink rakuStringSpecial  SpecialChar

    HiLink rakuPodAbbr         rakuPod
    HiLink rakuPodAbbrEOF      rakuPod
    HiLink rakuPodAbbrNoCode   rakuPod
    HiLink rakuPodAbbrCode     rakuPodCode
    HiLink rakuPodPara         rakuPod
    HiLink rakuPodParaEOF      rakuPod
    HiLink rakuPodParaNoCode   rakuPod
    HiLink rakuPodParaCode     rakuPodCode
    HiLink rakuPodDelim        rakuPod
    HiLink rakuPodDelimEOF     rakuPod
    HiLink rakuPodDelimNoCode  rakuPod
    HiLink rakuPodDelimCode    rakuPodCode
    HiLink rakuPodImplicitCode rakuPodCode
    HiLink rakuPodExtraConfig  rakuPodPrefix
    HiLink rakuPodVerticalBar  rakuPodFormatCode
    HiLink rakuPodColon        rakuPodFormatCode
    HiLink rakuPodSemicolon    rakuPodFormatCode
    HiLink rakuPodComma        rakuPodFormatCode
    HiLink rakuPodFormatOne    rakuPodFormat
    HiLink rakuPodFormatTwo    rakuPodFormat
    HiLink rakuPodFormatThree  rakuPodFormat
    HiLink rakuPodFormatFrench rakuPodFormat

    HiLink rakuPodType           Type
    HiLink rakuPodConfigOption   String
    HiLink rakuPodCode           PreProc
    HiLink rakuPod               Comment
    HiLink rakuPodComment        Comment
    HiLink rakuPodAutoQuote      Operator
    HiLink rakuPodConfigOperator Operator
    HiLink rakuPodPrefix         Statement
    HiLink rakuPodName           Identifier
    HiLink rakuPodFormatCode     SpecialChar
    HiLink rakuPodFormat         SpecialComment

    delcommand HiLink
endif

if exists("raku_fold") || exists("raku_extended_all")
    setl foldmethod=syntax
    syn region rakuBlockFold
        \ start="^\z(\s*\)\%(my\|our\|augment\|multi\|proto\|only\)\?\s*\%(\%([A-Za-z_\xC0-\xFF]\%([A-Za-z_\xC0-\xFF0-9]\|[-'][A-Za-z_\xC0-\xFF]\@=\)*\)\s\+\)\?\<\%(CATCH\|try\|ENTER\|LEAVE\|CHECK\|INIT\|BEGIN\|END\|KEEP\|UNDO\|PRE\|POST\|module\|package\|enum\|subset\|class\|sub\%(method\)\?\|multi\|method\|slang\|grammar\|regex\|token\|rule\)\>[^{]\+\%({\s*\%(#.*\)\?\)\?$"
        \ end="^\z1}"
        \ transparent fold keepend extend
endif

let b:current_syntax = "raku"

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:ts=8:sts=4:sw=4:expandtab:ft=vim
