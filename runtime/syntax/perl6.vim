" Vim syntax file
" Language:      Perl 6
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Homepage:      http://github.com/vim-perl/vim-perl/tree/master
" Bugs/requests: http://github.com/vim-perl/vim-perl/issues
" Last Change:   2013-07-21

" Contributors:  Luke Palmer <fibonaci@babylonia.flatirons.org>
"                Moritz Lenz <moritz@faui2k3.org>
"                Hinrik Örn Sigurðsson <hinrik.sig@gmail.com>
"
" This is a big undertaking. Perl 6 is the sort of language that only Perl
" can parse. But I'll do my best to get vim to.
"
" You can associate the extension ".pl" with the filetype "perl6" by setting
"     autocmd BufNewFile,BufRead *.pl setf perl6
" in your ~/.vimrc. But that will infringe on Perl 5, so you might want to
" put a modeline near the beginning or end of your Perl 6 files instead:
"     # vim: filetype=perl6

" TODO:
"   * Deal with s:Perl5//
"   * m:s// is a match, not a substitution
"   * Make these highlight as strings, not operators:
"       <==> <=:=> <===> <=~> <« »> «>» «<»
"   * Allow more keywords to match as function calls(leave() is export(), etc)
"   * Optimization: use nextgroup instead of lookaround (:help syn-nextgroup)
"   * Fix s''' substitutions being matched as package names
"   * Match s/// and m/// better, so things like "$s/" won't match
"   * Add more support for folding (:help syn-fold)
"   * Add more syntax syncing hooks (:help syn-sync)
"   * Q//:
"       :to, :heredoc
"       interpolate \q:s{$scalar} (though the spec isn't very clear on it)
"
" Impossible TODO?:
"   * Unspace
"   * Unicode bracketing characters for quoting (there are so many)
"   * Various tricks depending on context. I.e. we can't know when Perl
"     expects «*» to be a string or a hyperoperator. The latter is presumably
"     more common, so that's what we assume.
"   * Selective highlighting of Pod formatting codes with the :allow option
"   * Arbitrary number, order, and negation of adverbs to Q//, q//, qq//.
"     Currently only the first adverb is considered significant. Anything
"     more would require an exponential amount of regexes, making this
"     already slow syntax file even slower.
"
" If you want to have Pir code inside Q:PIR// strings highlighted, do:
"  let perl6_embedded_pir=1
"
" The above requires pir.vim, which you can find in Parrot's repository:
" https://svn.parrot.org/parrot/trunk/editor/
"
" Some less than crucial things have been made optional to speed things up.
" Look at the comments near the if/else branches in this file to see exactly
" which features are affected. "perl6_extended_all" enables everything.
"
" The defaults are:
"
"  unlet perl6_extended_comments
"  unlet perl6_extended_q
"  unlet perl6_extended_all

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
    syntax clear
elseif exists("b:current_syntax")
    finish
endif
let s:keepcpo= &cpo
set cpo&vim

" identifiers
syn match p6Normal display "\K\%(\k\|[-']\K\@=\)*"

" This is used in the for loops below
" Don't use the "syn keyword" construct because that always has higher
" priority than matches/regions, so the words can't be autoquoted with
" the "=>" and "p5=>" operators. All the lookaround stuff is to make sure
" we don't match them as part of some other identifier.
let s:before_keyword = " display \"\\%(\\k\\|\\K\\@<=[-']\\)\\@<!\\%("
let s:after_keyword = "\\)\\%(\\k\\|[-']\\K\\@=\\)\\@!\""

" Billions of keywords
let s:keywords = {
 \ "p6Attention": [
 \   "ACHTUNG ATTN ATTENTION FIXME NB TODO TBD WTF XXX NOTE",
 \ ],
 \ "p6DeclareRoutine": [
 \   "macro sub submethod method multi proto only rule token regex category",
 \ ],
 \ "p6Module": [
 \   "module class role package enum grammar slang subset",
 \ ],
 \ "p6Variable": [
 \   "self",
 \ ],
 \ "p6Include": [
 \   "use require",
 \ ],
 \ "p6Conditional": [
 \   "if else elsif unless",
 \ ],
 \ "p6VarStorage": [
 \   "let my our state temp has constant",
 \ ],
 \ "p6Repeat": [
 \   "for loop repeat while until gather given",
 \ ],
 \ "p6FlowControl": [
 \   "take do when next last redo return contend maybe defer",
 \   "default exit make continue break goto leave async lift",
 \ ],
 \ "p6TypeConstraint": [
 \   "is as but trusts of returns handles where augment supersede",
 \ ],
 \ "p6ClosureTrait": [
 \   "BEGIN CHECK INIT START FIRST ENTER LEAVE KEEP",
 \   "UNDO NEXT LAST PRE POST END CATCH CONTROL TEMP",
 \ ],
 \ "p6Exception": [
 \   "die fail try warn",
 \ ],
 \ "p6Property": [
 \   "prec irs ofs ors export deep binary unary reparsed rw parsed cached",
 \   "readonly defequiv will ref copy inline tighter looser equiv assoc",
 \   "required",
 \ ],
 \ "p6Number": [
 \   "NaN Inf",
 \ ],
 \ "p6Pragma": [
 \   "oo fatal",
 \ ],
 \ "p6Type": [
 \   "Object Any Junction Whatever Capture Match",
 \   "Signature Proxy Matcher Package Module Class",
 \   "Grammar Scalar Array Hash KeyHash KeySet KeyBag",
 \   "Pair List Seq Range Set Bag Mapping Void Undef",
 \   "Failure Exception Code Block Routine Sub Macro",
 \   "Method Submethod Regex Str Blob Char Byte",
 \   "Codepoint Grapheme StrPos StrLen Version Num",
 \   "Complex num complex Bit bit bool True False",
 \   "Increasing Decreasing Ordered Callable AnyChar",
 \   "Positional Associative Ordering KeyExtractor",
 \   "Comparator OrderingPair IO KitchenSink Role",
 \   "Int int int1 int2 int4 int8 int16 int32 int64",
 \   "Rat rat rat1 rat2 rat4 rat8 rat16 rat32 rat64",
 \   "Buf buf buf1 buf2 buf4 buf8 buf16 buf32 buf64",
 \   "UInt uint uint1 uint2 uint4 uint8 uint16 uint32",
 \   "uint64 Abstraction utf8 utf16 utf32",
 \ ],
 \ "p6Operator": [
 \   "div x xx mod also leg cmp before after eq ne le lt",
 \   "gt ge eqv ff fff and andthen Z X or xor",
 \   "orelse extra m mm rx s tr",
 \ ],
\ }

for [group, words] in items(s:keywords)
    let s:words_space = join(words, " ")
    let s:temp = split(s:words_space)
    let s:words = join(s:temp, "\\|")
    exec "syn match ". group ." ". s:before_keyword . s:words . s:after_keyword
endfor
unlet s:keywords s:words_space s:temp s:words

" More operators
" Don't put a "\+" at the end of the character class. That makes it so
" greedy that the "%" " in "+%foo" won't be allowed to match as a sigil,
" among other things
syn match p6Operator display "[-+/*~?|=^!%&,<>.;\\]"
syn match p6Operator display "\%(:\@<!::\@!\|::=\|\.::\)"
" these require whitespace on the left side
syn match p6Operator display "\%(\s\|^\)\@<=\%(xx=\|p5=>\)"
" "i" requires a digit to the left, and no keyword char to the right
syn match p6Operator display "\d\@<=i\k\@!"
" index overloading
syn match p6Operator display "\%(&\.(\@=\|@\.\[\@=\|%\.{\@=\)"

" all infix operators except nonassocative ones
let s:infix_a = [
    \ "div % mod +& +< +> \\~& ?& \\~< \\~> +| +\\^ \\~| \\~\\^ ?| ?\\^ xx x",
    \ "\\~ && & also <== ==> <<== ==>> == != < <= > >= \\~\\~ eq ne lt le gt",
    \ "ge =:= === eqv before after \\^\\^ min max \\^ff ff\\^ \\^ff\\^",
    \ "\\^fff fff\\^ \\^fff\\^ fff ff ::= := \\.= => , : p5=> Z minmax",
    \ "\\.\\.\\. and andthen or orelse xor \\^ += -= /= \\*= \\~= //= ||=",
    \ "+ - \\*\\* \\* // / \\~ || |",
\ ]
" nonassociative infix operators
let s:infix_n = "but does <=> leg cmp \\.\\. \\.\\.\\^\\^ \\^\\.\\. \\^\\.\\.\\^"

let s:infix_a_long = join(s:infix_a, " ")
let s:infix_a_words = split(s:infix_a_long)
let s:infix_a_pattern = join(s:infix_a_words, "\\|")

let s:infix_n_words = split(s:infix_n)
let s:infix_n_pattern = join(s:infix_n_words, "\\|")

let s:both = [s:infix_a_pattern, s:infix_n_pattern]
let s:infix = join(s:both, "\\|")

let s:infix_assoc = "!\\?\\%(" . s:infix_a_pattern . "\\)"
let s:infix = "!\\?\\%(" . s:infix . "\\)"

unlet s:infix_a s:infix_a_long s:infix_a_words s:infix_a_pattern
unlet s:infix_n s:infix_n_pattern s:both

" [+] reduce
exec "syn match p6ReduceOp display \"\\k\\@<!\\[[R\\\\]\\?!\\?". s:infix_assoc ."]\\%(«\\|<<\\)\\?\""
unlet s:infix_assoc

" Reverse and cross operators (Rop, Xop)
exec "syn match p6ReverseCrossOp display \"[RX]". s:infix ."\""

" q() or whatever() is always a function call
syn match p6Normal display "\K\%(\k\|[-']\K\@=\)*(\@="

" basically all builtins that can be followed by parentheses
let s:routines = [
 \ "eager hyper substr index rindex grep map sort join lines hints chmod",
 \ "split reduce min max reverse truncate zip cat roundrobin classify",
 \ "first sum keys values pairs defined delete exists elems end kv any",
 \ "all one wrap shape key value name pop push shift splice unshift floor",
 \ "ceiling abs exp log log10 rand sign sqrt sin cos tan round strand",
 \ "roots cis unpolar polar atan2 pick chop p5chop chomp p5chomp lc",
 \ "lcfirst uc ucfirst capitalize normalize pack unpack quotemeta comb",
 \ "samecase sameaccent chars nfd nfc nfkd nfkc printf sprintf caller",
 \ "evalfile run runinstead nothing want bless chr ord gmtime time eof",
 \ "localtime gethost getpw chroot getlogin getpeername kill fork wait",
 \ "perl graphs codes bytes clone print open read write readline say seek",
 \ "close opendir readdir slurp pos fmt vec link unlink symlink uniq pair",
 \ "asin atan sec cosec cotan asec acosec acotan sinh cosh tanh asinh",
 \ "acos acosh atanh sech cosech cotanh sech acosech acotanh asech ok",
 \ "plan_ok dies_ok lives_ok skip todo pass flunk force_todo use_ok isa_ok",
 \ "diag is_deeply isnt like skip_rest unlike cmp_ok eval_dies_ok nok_error",
 \ "eval_lives_ok approx is_approx throws_ok version_lt plan eval succ pred",
 \ "times nonce once signature new connect operator undef undefine sleep",
 \ "from to infix postfix prefix circumfix postcircumfix minmax lazy count",
 \ "unwrap getc pi e context void quasi body each contains rewinddir subst",
 \ "can isa flush arity assuming rewind callwith callsame nextwith nextsame",
 \ "attr eval_elsewhere none srand trim trim_start trim_end lastcall WHAT",
 \ "WHERE HOW WHICH VAR WHO WHENCE ACCEPTS REJECTS does not true iterator by",
 \ "re im invert flip",
\ ]

" we want to highlight builtins like split() though, so this comes afterwards
" TODO: check if this would be faster as one big regex
let s:words_space = join(s:routines, " ")
let s:temp = split(s:words_space)
let s:words = join(s:temp, "\\|")
exec "syn match p6Routine ". s:before_keyword . s:words . s:after_keyword
unlet s:before_keyword s:after_keyword s:words_space s:temp s:words s:routines

" packages, must come after all the keywords
syn match p6Normal display "\%(::\)\@<=\K\%(\k\|[-']\K\@=\)*"
syn match p6Normal display "\K\%(\k\|[-']\K\@=\)*\%(::\)\@="

" some standard packages
syn match p6Type display "\%(::\|\k\|\K\@<=[-']\)\@<!\%(Order\%(::Same\|::Increase\|::Decrease\)\?\)\%(\k\|[-']\K\@=\)\@!"
syn match p6Type display "\%(::\|\k\|\K\@<=[-']\)\@<!\%(Bool\%(::True\|::False\)\?\)\%(\k\|[-']\K\@=\)\@!"


syn match p6Shebang    display "\%^#!.*"
syn match p6BlockLabel display "\%(^\s*\)\@<=\h\w*\s*::\@!\_s\@="
syn match p6Number     display "\k\@<!_\@!\%(\d\|__\@!\)\+_\@<!\%([eE]_\@!+\?\%(\d\|_\)\+\)\?_\@<!"
syn match p6Float      display "\k\@<!_\@!\%(\d\|__\@!\)\+_\@<![eE]_\@!-\%(\d\|_\)\+"
syn match p6Float      display "\k\@<!_\@<!\%(\d\|__\@!\)*_\@<!\.\@<!\._\@!\.\@!\a\@!\%(\d\|_\)\+_\@<!\%([eE]_\@!\%(\d\|_\)\+\)\?"

syn match p6NumberBase display "[obxd]" contained
syn match p6Number     display "\<0\%(o[0-7][0-7_]*\)\@="     nextgroup=p6NumberBase
syn match p6Number     display "\<0\%(b[01][01_]*\)\@="       nextgroup=p6NumberBase
syn match p6Number     display "\<0\%(x\x[[:xdigit:]_]*\)\@=" nextgroup=p6NumberBase
syn match p6Number     display "\<0\%(d\d[[:digit:]_]*\)\@="  nextgroup=p6NumberBase
syn match p6Number     display "\%(\<0o\)\@<=[0-7][0-7_]*"
syn match p6Number     display "\%(\<0b\)\@<=[01][01_]*"
syn match p6Number     display "\%(\<0x\)\@<=\x[[:xdigit:]_]*"
syn match p6Number     display "\%(\<0d\)\@<=\d[[:digit:]_]*"

syn match p6Version    display "\<v\d\@=" nextgroup=p6VersionNum
syn match p6VersionNum display "\d\+" nextgroup=p6VersionDot contained
syn match p6VersionDot display "\.\%(\d\|\*\)\@=" nextgroup=p6VersionNum contained

" try to distinguish the "is" function from the "is" trail auxiliary
syn match p6Routine     display "\%(\%(\S\k\@<!\|^\)\s*\)\@<=is\>"

" does is a type constraint sometimes
syn match p6TypeConstraint display "does\%(\s*\%(\k\|[-']\K\@=\)\)\@="

" int is a type sometimes
syn match p6Type        display "\<int\>\%(\s*(\|\s\+\d\)\@!"

" these Routine names are also Properties, if preceded by "is"
syn match p6Property    display "\%(is\s\+\)\@<=\%(signature\|context\|also\|shape\)"

" The sigil in ::*Package
syn match p6PackageTwigil display "\%(::\)\@<=\*"

" $<match>
syn region p6MatchVarSigil
    \ matchgroup=p6Variable
    \ start="\$\%(<<\@!\)\@="
    \ end=">\@<="
    \ contains=p6MatchVar

syn region p6MatchVar
    \ matchgroup=p6Twigil
    \ start="<"
    \ end=">"
    \ contained

" Contextualizers
syn match p6Context display "\<\%(item\|list\|slice\|hash\)\>"
syn match p6Context display "\%(\$\|@\|%\|&\|@@\)(\@="

" the "$" placeholder in "$var1, $, var2 = @list"
syn match p6Placeholder display "\%(,\s*\)\@<=\$\%(\K\|\%([.^*?=!~]\|:\@<!::\@!\)\)\@!"
syn match p6Placeholder display "\$\%(\K\|\%([.^*?=!~]\|:\@<!::\@!\)\)\@!\%(,\s*\)\@="

" Quoting

" one cluster for every quote adverb
syn cluster p6Interp_s
    \ add=p6InterpScalar
syn cluster p6Interp_scalar
    \ add=p6InterpScalar

syn cluster p6Interp_a
    \ add=p6InterpArray
syn cluster p6Interp_array
    \ add=p6InterpArray

syn cluster p6Interp_h
    \ add=p6InterpHash
syn cluster p6Interp_hash
    \ add=p6InterpHash

syn cluster p6Interp_f
    \ add=p6InterpFunction
syn cluster p6Interp_f
    \ add=p6InterpFunction

syn cluster p6Interp_c
    \ add=p6InterpClosure
syn cluster p6Interp_closure
    \ add=p6InterpClosure


if exists("perl6_extended_q") || exists("perl6_extended_all")
    syn cluster p6Interp_ww
        \ add=p6StringSQ
        \ add=p6StringDQ
    syn cluster p6Interp_quotewords
        \ add=p6StringSQ
        \ add=p6StringDQ
endif

syn cluster p6Interp_q
    \ add=p6EscQQ
    \ add=p6EscBackSlash
syn cluster p6Interp_single
    \ add=p6EscQQ
    \ add=p6EscBackSlash

syn cluster p6Interp_b
    \ add=@p6Interp_q
    \ add=p6Escape
    \ add=p6EscOpenCurly
    \ add=p6EscCodePoint
    \ add=p6EscHex
    \ add=p6EscOct
    \ add=p6EscOctOld
    \ add=p6EscNull
syn cluster p6Interp_backslash
    \ add=@p6Interp_q
    \ add=p6Escape
    \ add=p6EscOpenCurly
    \ add=p6EscCodePoint
    \ add=p6EscHex
    \ add=p6EscOct
    \ add=p6EscOctOld
    \ add=p6EscNull

syn cluster p6Interp_qq
    \ add=@p6Interp_scalar
    \ add=@p6Interp_array
    \ add=@p6Interp_hash
    \ add=@p6Interp_function
    \ add=@p6Interp_closure
    \ add=@p6Interp_backslash
syn cluster p6Interp_double
    \ add=@p6Interp_scalar
    \ add=@p6Interp_array
    \ add=@p6Interp_hash
    \ add=@p6Interp_function
    \ add=@p6Interp_closure
    \ add=@p6Interp_backslash

syn region p6InterpScalar
    \ start="\ze\z(\$\%(\%(\%(\d\+\|!\|/\|¢\)\|\%(\%(\%([.^*?=!~]\|:\@<!::\@!\)\K\@=\)\?\K\%(\k\|[-']\K\@=\)*\)\%(\.\%(\K\%(\k\|[-']\K\@=\)*\)\|\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)*\)\.\?\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)\)"
    \ start="\ze\z(\$\%(\%(\%(\%([.^*?=!~]\|:\@<!::\@!\)\K\@=\)\?\K\%(\k\|[-']\K\@=\)*\)\|\%(\d\+\|!\|/\|¢\)\)\)"
    \ end="\z1\zs"
    \ contained
    \ contains=TOP
    \ keepend

syn region p6InterpScalar
    \ matchgroup=p6Context
    \ start="\$\ze()\@!"
    \ skip="([^)]*)"
    \ end=")\zs"
    \ contained
    \ contains=TOP

syn region p6InterpArray
    \ start="\ze\z(@\$*\%(\%(\%(!\|/\|¢\)\|\%(\%(\%([.^*?=!~]\|:\@<!::\@!\)\K\@=\)\?\K\%(\k\|[-']\K\@=\)*\)\%(\.\%(\K\%(\k\|[-']\K\@=\)*\)\|\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)*\)\.\?\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)\)"
    \ end="\z1\zs"
    \ contained
    \ contains=TOP
    \ keepend

syn region p6InterpArray
    \ matchgroup=p6Context
    \ start="@\ze()\@!"
    \ start="@@\ze()\@!"
    \ skip="([^)]*)"
    \ end=")\zs"
    \ contained
    \ contains=TOP

syn region p6InterpHash
    \ start="\ze\z(%\$*\%(\%(\%(!\|/\|¢\)\|\%(\%(\%([.^*?=!~]\|:\@<!::\@!\)\K\@=\)\?\K\%(\k\|[-']\K\@=\)*\)\%(\.\%(\K\%(\k\|[-']\K\@=\)*\)\|\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)*\)\.\?\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)\)"
    \ end="\z1\zs"
    \ contained
    \ contains=TOP
    \ keepend

syn region p6InterpHash
    \ matchgroup=p6Context
    \ start="%\ze()\@!"
    \ skip="([^)]*)"
    \ end=")\zs"
    \ contained
    \ contains=TOP

syn region p6InterpFunction
    \ start="\ze\z(&\%(\%(!\|/\|¢\)\|\%(\%(\%([.^*?=!~]\|:\@<!::\@!\)\K\@=\)\?\K\%(\k\|[-']\K\@=\)*\%(\.\%(\K\%(\k\|[-']\K\@=\)*\)\|\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)*\)\.\?\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\)\)"
    \ end="\z1\zs"
    \ contained
    \ contains=TOP
    \ keepend

syn region p6InterpFunction
    \ matchgroup=p6Context
    \ start="&\ze()\@!"
    \ skip="([^)]*)"
    \ end=")\zs"
    \ contained
    \ contains=TOP

syn region p6InterpClosure
    \ start="\\\@<!{}\@!"
    \ skip="{[^}]*}"
    \ end="}"
    \ contained
    \ contains=TOP
    \ keepend

" generic escape
syn match p6Escape          display "\\\S" contained

" escaped closing delimiters
syn match p6EscQuote        display "\\'" contained
syn match p6EscDoubleQuote  display "\\\"" contained
syn match p6EscCloseAngle   display "\\>" contained
syn match p6EscCloseFrench  display "\\»" contained
syn match p6EscBackTick     display "\\`" contained
syn match p6EscForwardSlash display "\\/" contained
syn match p6EscVerticalBar  display "\\|" contained
syn match p6EscExclamation  display "\\!" contained
syn match p6EscComma        display "\\," contained
syn match p6EscDollar       display "\\\$" contained
syn match p6EscCloseCurly   display "\\}" contained
syn match p6EscCloseBracket display "\\\]" contained

" misc escapes
syn match p6EscOctOld    display "\\\d\{1,3}" contained
syn match p6EscNull      display "\\0\d\@!" contained
syn match p6EscCodePoint display "\%(\\c\)\@<=\%(\d\|\S\|\[\)\@=" contained nextgroup=p6CodePoint
syn match p6EscHex       display "\%(\\x\)\@<=\%(\x\|\[\)\@=" contained nextgroup=p6HexSequence
syn match p6EscOct       display "\%(\\o\)\@<=\%(\o\|\[\)\@=" contained nextgroup=p6OctSequence
syn match p6EscQQ        display "\\qq" contained nextgroup=p6QQSequence
syn match p6EscOpenCurly display "\\{" contained
syn match p6EscHash      display "\\#" contained
syn match p6EscBackSlash display "\\\\" contained

syn region p6QQSequence
    \ matchgroup=p6Escape
    \ start="\["
    \ skip="\[[^\]]*]"
    \ end="]"
    \ contained
    \ transparent
    \ contains=@p6Interp_qq

syn match p6CodePoint   display "\%(\d\+\|\S\)" contained
syn region p6CodePoint
    \ matchgroup=p6Escape
    \ start="\["
    \ end="]"
    \ contained

syn match p6HexSequence display "\x\+" contained
syn region p6HexSequence
    \ matchgroup=p6Escape
    \ start="\["
    \ end="]"
    \ contained

syn match p6OctSequence display "\o\+" contained
syn region p6OctSequence
    \ matchgroup=p6Escape
    \ start="\["
    \ end="]"
    \ contained

" matches :key, :!key, :$var, :key<var>, etc
" Since we don't know in advance how the adverb ends, we use a trick.
" Consume nothing with the start pattern (\ze at the beginning),
" while capturing the whole adverb into \z1 and then putting it before
" the match start (\zs) of the end pattern.
syn region p6Adverb
    \ start="\ze\z(:!\?\K\%(\k\|[-']\K\@=\)*\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\?\)"
    \ start="\ze\z(:!\?[@$%]\$*\%(::\|\%(\$\@<=\d\+\|!\|/\|¢\)\|\%(\%([.^*?=!~]\|:\@<!::\@!\)\K\)\|\%(\K\%(\k\|[-']\K\@=\)*\)\)\)"
    \ end="\z1\zs"
    \ contained
    \ contains=TOP
    \ keepend

" <words>
" FIXME: not sure how to distinguish this from the "less than" operator
" in all cases. For now, it matches if any of the following is true:
"
" * There is whitespace missing on either side of the "<", since
"   people tend to put spaces around "less than"
" * It comes after "enum", "for", "any", "all", or "none"
" * It's the first or last thing on a line (ignoring whitespace)
" * It's preceded by "= "
"
" It never matches when:
"
" * Preceded by [<+~=] (e.g. <<foo>>, =<$foo>)
" * Followed by [-=] (e.g. <--, <=, <==)
syn region p6StringAngle
    \ matchgroup=p6Quote
    \ start="\%(\<\%(enum\|for\|any\|all\|none\)\>\s*(\?\s*\)\@<=<\%(<\|=>\|[-=]\{1,2}>\@!\)\@!"
    \ start="\%(\s\|[<+~=]\)\@<!<\%(<\|=>\|[-=]\{1,2}>\@!\)\@!"
    \ start="[<+~=]\@<!<\%(\s\|<\|=>\|[-=]\{1,2}>\@!\)\@!"
    \ start="\%(^\s*\)\@<=<\%(<\|=>\|[-=]\{1,2}>\@!\)\@!"
    \ start="[<+~=]\@<!<\%(\s*$\)\@="
    \ start="\%(=\s\+\)\@=<\%(<\|=>\|[-=]\{1,2}>\@!\)\@!"
    \ skip="\\\@<!\\>"
    \ end=">"
    \ contains=p6InnerAnglesOne,p6EscBackSlash,p6EscCloseAngle

syn region p6InnerAnglesOne
    \ matchgroup=p6StringAngle
    \ start="<"
    \ skip="\\\@<!\\>"
    \ end=">"
    \ transparent
    \ contained
    \ contains=p6InnerAnglesOne

" <<words>>
syn region p6StringAngles
    \ matchgroup=p6Quote
    \ start="<<=\@!"
    \ skip="\\\@<!\\>"
    \ end=">>"
    \ contains=p6InnerAnglesTwo,@p6Interp_qq,p6Comment,p6EscHash,p6EscCloseAngle,p6Adverb,p6StringSQ,p6StringDQ

syn region p6InnerAnglesTwo
    \ matchgroup=p6StringAngles
    \ start="<<"
    \ skip="\\\@<!\\>"
    \ end=">>"
    \ transparent
    \ contained
    \ contains=p6InnerAnglesTwo

" «words»
syn region p6StringFrench
    \ matchgroup=p6Quote
    \ start="«"
    \ skip="\\\@<!\\»"
    \ end="»"
    \ contains=p6InnerFrench,@p6Interp_qq,p6Comment,p6EscHash,p6EscCloseFrench,p6Adverb,p6StringSQ,p6StringDQ

syn region p6InnerFrench
    \ matchgroup=p6StringFrench
    \ start="«"
    \ skip="\\\@<!\\»"
    \ end="»"
    \ transparent
    \ contained
    \ contains=p6InnerFrench

" 'string'
syn region p6StringSQ
    \ matchgroup=p6Quote
    \ start="'"
    \ skip="\\\@<!\\'"
    \ end="'"
    \ contains=@p6Interp_q,p6EscQuote

" "string"
syn region p6StringDQ
    \ matchgroup=p6Quote
    \ start=+"+
    \ skip=+\\\@<!\\"+
    \ end=+"+
    \ contains=@p6Interp_qq,p6EscDoubleQuote

" Q// and friends.

syn match p6QuoteQ display "\%([Qq]\%(ww\|to\|[qwxsahfcb]\)\?\)\>" nextgroup=p6QPairs skipwhite skipempty
syn match p6QPairs contained transparent skipwhite skipempty nextgroup=p6StringQ,p6StringQ_PIR "\%(\_s*:!\?\K\%(\k\|[-']\K\@=\)*\%(([^)]*)\|\[[^\]]*]\|<[^>]*>\|«[^»]*»\|{[^}]*}\)\?\)*"

if exists("perl6_embedded_pir")
    syn include @p6PIR syntax/pir.vim
endif

" hardcoded set of delimiters
let s:delims = [
  \ ["\\\"",         "\\\"", "p6EscDoubleQuote",  "\\\\\\@<!\\\\\\\""],
  \ ["'",            "'",    "p6EscQuote",        "\\\\\\@<!\\\\'"],
  \ ["/",            "/",    "p6EscForwardSlash", "\\\\\\@<!\\\\/"],
  \ ["`",            "`",    "p6EscBackTick",     "\\\\\\@<!\\\\`"],
  \ ["|",            "|",    "p6EscVerticalBar",  "\\\\\\@<!\\\\|"],
  \ ["!",            "!",    "p6EscExclamation",  "\\\\\\@<!\\\\!"],
  \ [",",            ",",    "p6EscComma",        "\\\\\\@<!\\\\,"],
  \ ["\\$",          "\\$",  "p6EscDollar",       "\\\\\\@<!\\\\\\$"],
  \ ["{",            "}",    "p6EscCloseCurly",   "\\%(\\\\\\@<!\\\\}\\|{[^}]*}\\)"],
  \ ["<",            ">",    "p6EscCloseAngle",   "\\%(\\\\\\@<!\\\\>\\|<[^>]*>\\)"],
  \ ["«",            "»",    "p6EscCloseFrench",  "\\%(\\\\\\@<!\\\\»\\|«[^»]*»\\)"],
  \ ["\\\[",         "]",    "p6EscCloseBracket", "\\%(\\\\\\@<!\\\\]\\|\\[^\\]]*]\\)"],
  \ ["\\s\\@<=(",    ")",    "p6EscCloseParen",   "\\%(\\\\\\@<!\\\\)\\|([^)]*)\\)"],
\ ]

" double and triple delimiters too
if exists("perl6_extended_q") || exists("perl6_extended_all")
    call add(s:delims, ["««",           "»»",  "p6EscCloseFrench",  "\\%(\\\\\\@<!\\\\»»\\|««\\%([^»]\\|»»\\@!\\)*»»\\)"])
    call add(s:delims, ["«««",          "»»»", "p6EscCloseFrench",  "\\%(\\\\\\@<!\\\\»»»\\|«««\\%([^»]\\|»\\%(»»\\)\\@!\\)*»»»\\)"])
    call add(s:delims, ["{{",           "}}",  "p6EscCloseCurly",   "\\%(\\\\\\@<!\\\\}}\\|{{\\%([^}]\\|}}\\@!\\)*}}\\)"])
    call add(s:delims, ["{{{",          "}}}", "p6EscCloseCurly",   "\\%(\\\\\\@<!\\\\}}}\\|{{{\\%([^}]\\|}\\%(}}\\)\\@!\\)*}}}\\)"])
    call add(s:delims, ["\\\[\\\[",     "]]",  "p6EscCloseBracket", "\\%(\\\\\\@<!\\\\]]\\|\\[\\[\\%([^\\]]\\|]]\\@!\\)*]]\\)"])
    call add(s:delims, ["\\\[\\\[\\\[", "]]]", "p6EscCloseBracket", "\\%(\\\\\\@<!\\\\]]]\\|\\[\\[\\[\\%([^\\]]\\|]\\%(]]\\)\\@!\\)*]]]\\)"])
    call add(s:delims, ["\\s\\@<=((",   "))",  "p6EscCloseParen",   "\\%(\\\\\\@<!\\\\))\\|((\\%([^)]\\|))\\@!\\)*))\\)"])
    call add(s:delims, ["\\s\\@<=(((",  ")))", "p6EscCloseParen",   "\\%(\\\\\\@<!\\\\)))\\|(((\\%([^)]\\|)\\%())\\)\\@!\\)*)))\\)"])
    call add(s:delims, ["\\s\\@<=<<",   ">>",  "p6EscCloseAngle",   "\\%(\\\\\\@<!\\\\>>\\|<<\\%([^>]\\|>>\\@!\\)*>>\\)"])
    call add(s:delims, ["\\s\\@<=<<<",  ">>>", "p6EscCloseAngle",   "\\%(\\\\\\@<!\\\\>>>\\|<<<\\%([^>]\\|>\\%(>>\\)\\@!\\)*>>>\\)"])
endif

if !exists("perl6_extended_q") && !exists("perl6_extended_all")
    " simple version, no special highlighting within the string
    for [start_delim, end_delim, end_group, skip] in s:delims
        exec "syn region p6StringQ matchgroup=p6Quote start=\"".start_delim."\" skip=\"".skip."\" end=\"".end_delim."\" contains=".end_group." contained"
    endfor

    if exists("perl6_embedded_pir")
        " highlight embedded PIR code
        for [start_delim, end_delim, end_group, skip] in s:delims
            exec "syn region p6StringQ_PIR matchgroup=p6Quote start=\"\\%(Q\\s*:PIR\\s*\\)\\@<=".start_delim."\" skip=\"".skip."\" end=\"".end_delim."\" contains=@p6PIR,".end_group." contained"
        endfor
    endif
else
    let s:before = "syn region p6StringQ matchgroup=p6Quote start=\"\\%("
    let s:after  = "\\%(\\_s*:!\\?\\K\\%(\\k\\|[-']\\K\\@=\\)*\\%(([^)]*)\\|\\[[^\\]]*]\\|<[^>]*>\\|«[^»]*»\\|{[^}]*}\\)\\?\\)*\\_s*\\)\\@<="

    let s:adverbs = [
        \ ["s", "scalar"],
        \ ["a", "array"],
        \ ["h", "hash"],
        \ ["f", "function"],
        \ ["c", "closure"],
        \ ["b", "backslash"],
        \ ["w", "words"],
        \ ["ww", "quotewords"],
        \ ["x", "exec"],
    \ ]

    " these can't be conjoined with q and qq (e.g. as qqq and qqqq)
    let s:q_adverbs = [
        \ ["q", "single"],
        \ ["qq", "double"],
    \ ]

    for [start_delim, end_delim, end_group, skip] in s:delims
        " Q, q, and qq with any number of (ignored) adverbs
        exec s:before ."Q". s:after .start_delim."\" end=\"". end_delim ."\""." contained"
        exec s:before ."q". s:after .start_delim ."\" skip=\"". skip ."\" end=\"". end_delim ."\" contains=". end_group .",@p6Interp_q"." contained"
        exec s:before ."qq". s:after .start_delim ."\" skip=\"". skip ."\" end=\"". end_delim ."\" contains=". end_group .",@p6Interp_qq"." contained"

        for [short, long] in s:adverbs
            " Qs, qs, qqs, Qa, qa, qqa, etc, with ignored adverbs
            exec s:before ."Q".short. s:after .start_delim ."\" end=\"". end_delim ."\" contains=@p6Interp_".long." contained"
            exec s:before ."q".short. s:after .start_delim ."\" skip=\"". skip ."\" end=\"". end_delim ."\" contains=". end_group .",@p6Interp_q,@p6Interp_".long." contained"
            exec s:before ."qq".short. s:after .start_delim ."\" skip=\"". skip ."\" end=\"". end_delim ."\" contains=". end_group .",@p6Interp_qq,@p6Interp_".long." contained"

            " Q, q, and qq, with one significant adverb
            exec s:before ."Q\\s*:\\%(".short."\\|".long."\\)". s:after .start_delim ."\" end=\"". end_delim ."\" contains=@p6Interp_".long." contained"
            for [q_short, q_long] in s:q_adverbs
                exec s:before ."Q\\s*:\\%(".q_short."\\|".q_long."\\)". s:after .start_delim ."\" end=\"". end_delim ."\" contains=@p6Interp_".q_long." contained"
            endfor
            exec s:before ."q\\s*:\\%(".short."\\|".long."\\)". s:after .start_delim ."\" skip=\"". skip ."\" end=\"". end_delim ."\" contains=". end_group .",@p6Interp_q,@p6Interp_".long." contained"
            exec s:before ."qq\\s*:\\%(".short."\\|".long."\\)". s:after .start_delim ."\" skip=\"". skip ."\" end=\"". end_delim ."\" contains=". end_group .",@p6Interp_qq,@p6Interp_".long." contained"

            for [short2, long2] in s:adverbs
                " Qs, qs, qqs, Qa, qa, qqa, etc, with one significant adverb
                exec s:before ."Q".short."\\s*:\\%(".short2."\\|".long2."\\)". s:after .start_delim ."\" end=\"". end_delim ."\" contains=@p6Interp_".long.",@p6Interp_".long2." contained"
                for [q_short2, q_long2] in s:q_adverbs
                    exec s:before ."Q".short."\\s*:\\%(".q_short2."\\|".q_long2."\\)". s:after .start_delim ."\" end=\"". end_delim ."\" contains=@p6Interp_".long.",@p6Interp_".q_long2." contained"
                endfor
                exec s:before ."q".short."\\s*:\\%(".short2."\\|".long2."\\)". s:after .start_delim ."\" skip=\"". skip ."\" end=\"". end_delim ."\" contains=". end_group .",@p6Interp_q,@p6Interp_".long.",@p6Interp_".long2." contained"
                exec s:before ."qq".short."\\s*:\\%(".short2."\\|".long2."\\)". s:after .start_delim ."\" skip=\"". skip ."\" end=\"". end_delim ."\" contains=". end_group .",@p6Interp_qq,@p6Interp_".long.",@p6Interp_".long2." contained"
            endfor
        endfor
    endfor
    unlet s:before s:after s:adverbs s:q_adverbs
endif
unlet s:delims

" Match these so something else above can't. E.g. the "q" in "role q { }"
" should not be considered a string
syn match p6Normal display "\%(\<\%(role\|grammar\|slang\)\s\+\)\@<=\K\%(\k\|[-']\K\@=\)*"

" :key
syn match p6Operator display ":\@<!::\@!!\?" nextgroup=p6Key
syn match p6Key display "\k\%(\k\|[-']\K\@=\)*" contained

" => and p5=> autoquoting
syn match p6StringP5Auto display "\K\%(\k\|[-']\K\@=\)*\ze\s\+p5=>"
syn match p6StringAuto   display "\K\%(\k\|[-']\K\@=\)*\ze\%(p5\)\@<!=>"
syn match p6StringAuto   display "\K\%(\k\|[-']\K\@=\)*\ze\s\+=>"
syn match p6StringAuto   display "\K\%(\k\|[-']\K\@=\)*p5\ze=>"

" Hyperoperators. Needs to come after the quoting operators (<>, «», etc)
exec "syn match p6HyperOp display \"»"   .s:infix."»\\?\""
exec "syn match p6HyperOp display \"«\\?".s:infix."«\""
exec "syn match p6HyperOp display \"»"   .s:infix."«\""
exec "syn match p6HyperOp display \"«"   .s:infix. "»\""

exec "syn match p6HyperOp display \">>"          .s:infix."\\%(>>\\)\\?\""
exec "syn match p6HyperOp display \"\\%(<<\\)\\?".s:infix."<<\""
exec "syn match p6HyperOp display \">>"          .s:infix."<<\""
exec "syn match p6HyperOp display \"<<"          .s:infix.">>\""
unlet s:infix

" Regexes and grammars

syn match p6RegexName display "\%(\<\%(regex\|rule\|token\)\s\+\)\@<=\K\%(\k\|[-']\K\@=\)*" nextgroup=p6RegexBlockCrap skipwhite skipempty
syn match p6RegexBlockCrap "[^{]*" nextgroup=p6RegexBlock skipwhite skipempty transparent contained

syn region p6RegexBlock
    \ matchgroup=p6Normal
    \ start="{"
    \ end="}"
    \ contained
    \ contains=@p6Regexen,@p6Variables

" Perl 6 regex bits

syn cluster p6Regexen
    \ add=p6RxMeta
    \ add=p6RxEscape
    \ add=p6EscHex
    \ add=p6EscOct
    \ add=p6EscNull
    \ add=p6RxAnchor
    \ add=p6RxCapture
    \ add=p6RxGroup
    \ add=p6RxAlternation
    \ add=p6RxAdverb
    \ add=p6RxAdverbArg
    \ add=p6RxStorage
    \ add=p6RxAssertion
    \ add=p6RxQuoteWords
    \ add=p6RxClosure
    \ add=p6RxStringSQ
    \ add=p6RxStringDQ
    \ add=p6Comment

syn match p6RxMeta        display contained ".\%(\k\|\s\)\@<!"
syn match p6RxAnchor      display contained "[$^]"
syn match p6RxEscape      display contained "\\\S"
syn match p6RxCapture     display contained "[()]"
syn match p6RxAlternation display contained "|"
syn match p6RxRange       display contained "\.\."

syn region p6RxClosure
    \ matchgroup=p6Normal
    \ start="{"
    \ end="}"
    \ contained
    \ containedin=p6RxClosure
    \ contains=TOP
syn region p6RxGroup
    \ matchgroup=p6StringSpecial2
    \ start="\["
    \ end="]"
    \ contained
    \ contains=@p6Regexen,@p6Variables
syn region p6RxAssertion
    \ matchgroup=p6StringSpecial2
    \ start="<"
    \ end=">"
    \ contained
    \ contains=@p6Regexen,@p6Variables,p6RxCharClass,p6RxAssertCall
syn region p6RxAssertCall
    \ matchgroup=p6Normal
    \ start="\%(::\|\%(\K\%(\k\|[-']\K\@=\)*\)\)\@<=(\@="
    \ end=")\@<="
    \ contained
    \ contains=TOP
syn region p6RxCharClass
    \ matchgroup=p6StringSpecial2
    \ start="\%(<[-!+?]\?\)\@<=\["
    \ skip="\\]"
    \ end="]"
    \ contained
    \ contains=p6RxRange,p6RxEscape,p6EscHex,p6EscOct,p6EscNull
syn region p6RxQuoteWords
    \ matchgroup=p6StringSpecial2
    \ start="< "
    \ end=">"
    \ contained
syn region p6RxAdverb
    \ start="\ze\z(:!\?\K\%(\k\|[-']\K\@=\)*\)"
    \ end="\z1\zs"
    \ contained
    \ contains=TOP
    \ keepend
syn region p6RxAdverbArg
    \ start="\%(:!\?\K\%(\k\|[-']\K\@=\)*\)\@<=("
    \ skip="([^)]*)"
    \ end=")"
    \ contained
    \ contains=TOP
syn region p6RxStorage
    \ matchgroup=p6Operator
    \ start="\%(^\s*\)\@<=:\%(my\>\|temp\>\)\@="
    \ end="$"
    \ contains=TOP
    \ contained

" Perl 5 regex bits

syn cluster p6RegexP5Base
    \ add=p6RxP5Escape
    \ add=p6RxP5Oct
    \ add=p6RxP5Hex
    \ add=p6RxP5EscMeta
    \ add=p6RxP5CodePoint
    \ add=p6RxP5Prop

" normal regex stuff
syn cluster p6RegexP5
    \ add=@p6RegexP5Base
    \ add=p6RxP5Quantifier
    \ add=p6RxP5Meta
    \ add=p6RxP5QuoteMeta
    \ add=p6RxP5ParenMod
    \ add=p6RxP5Verb
    \ add=p6RxP5Count
    \ add=p6RxP5Named
    \ add=p6RxP5ReadRef
    \ add=p6RxP5WriteRef
    \ add=p6RxP5CharClass
    \ add=p6RxP5Anchor

" inside character classes
syn cluster p6RegexP5Class
    \ add=@p6RegexP5Base
    \ add=p6RxP5Posix
    \ add=p6RxP5Range

syn match p6RxP5Escape     display contained "\\\S"
syn match p6RxP5CodePoint  display contained "\\c\S\@=" nextgroup=p6RxP5CPId
syn match p6RxP5CPId       display contained "\S"
syn match p6RxP5Oct        display contained "\\\%(\o\{1,3}\)\@=" nextgroup=p6RxP5OctSeq
syn match p6RxP5OctSeq     display contained "\o\{1,3}"
syn match p6RxP5Anchor     display contained "[\^$]"
syn match p6RxP5Hex        display contained "\\x\%({\x\+}\|\x\{1,2}\)\@=" nextgroup=p6RxP5HexSeq
syn match p6RxP5HexSeq     display contained "\x\{1,2}"
syn region p6RxP5HexSeq
    \ matchgroup=p6RxP5Escape
    \ start="{"
    \ end="}"
    \ contained
syn region p6RxP5Named
    \ matchgroup=p6RxP5Escape
    \ start="\%(\\N\)\@<={"
    \ end="}"
    \ contained
syn match p6RxP5Quantifier display contained "\%([+*]\|(\@<!?\)"
syn match p6RxP5ReadRef    display contained "\\[1-9]\d\@!"
syn match p6RxP5ReadRef    display contained "\\k<\@=" nextgroup=p6RxP5ReadRefId
syn region p6RxP5ReadRefId
    \ matchgroup=p6RxP5Escape
    \ start="<"
    \ end=">"
    \ contained
syn match p6RxP5WriteRef   display contained "\\g\%(\d\|{\)\@=" nextgroup=p6RxP5WriteRefId
syn match p6RxP5WriteRefId display contained "\d\+"
syn region p6RxP5WriteRefId
    \ matchgroup=p6RxP5Escape
    \ start="{"
    \ end="}"
    \ contained
syn match p6RxP5Prop       display contained "\\[pP]\%(\a\|{\)\@=" nextgroup=p6RxP5PropId
syn match p6RxP5PropId     display contained "\a"
syn region p6RxP5PropId
    \ matchgroup=p6RxP5Escape
    \ start="{"
    \ end="}"
    \ contained
syn match p6RxP5Meta       display contained "[(|).]"
syn match p6RxP5ParenMod   display contained "(\@<=?\@=" nextgroup=p6RxP5Mod,p6RxP5ModName,p6RxP5Code
syn match p6RxP5Mod        display contained "?\%(<\?=\|<\?!\|[#:|]\)"
syn match p6RxP5Mod        display contained "?-\?[impsx]\+"
syn match p6RxP5Mod        display contained "?\%([-+]\?\d\+\|R\)"
syn match p6RxP5Mod        display contained "?(DEFINE)"
syn match p6RxP5Mod        display contained "?\%(&\|P[>=]\)" nextgroup=p6RxP5ModDef
syn match p6RxP5ModDef     display contained "\h\w*"
syn region p6RxP5ModName
    \ matchgroup=p6StringSpecial
    \ start="?'"
    \ end="'"
    \ contained
syn region p6RxP5ModName
    \ matchgroup=p6StringSpecial
    \ start="?P\?<"
    \ end=">"
    \ contained
syn region p6RxP5Code
    \ matchgroup=p6StringSpecial
    \ start="??\?{"
    \ end="})\@="
    \ contained
    \ contains=TOP
syn match p6RxP5EscMeta    display contained "\\[?*.{}()[\]|\^$]"
syn match p6RxP5Count      display contained "\%({\d\+\%(,\%(\d\+\)\?\)\?}\)\@=" nextgroup=p6RxP5CountId
syn region p6RxP5CountId
    \ matchgroup=p6RxP5Escape
    \ start="{"
    \ end="}"
    \ contained
syn match p6RxP5Verb       display contained "(\@<=\*\%(\%(PRUNE\|SKIP\|THEN\)\%(:[^)]*\)\?\|\%(MARK\|\):[^)]*\|COMMIT\|F\%(AIL\)\?\|ACCEPT\)"
syn region p6RxP5QuoteMeta
    \ matchgroup=p6RxP5Escape
    \ start="\\Q"
    \ end="\\E"
    \ contained
    \ contains=@p6Variables,p6EscBackSlash
syn region p6RxP5CharClass
    \ matchgroup=p6StringSpecial
    \ start="\[\^\?"
    \ skip="\\]"
    \ end="]"
    \ contained
    \ contains=@p6RegexP5Class
syn region p6RxP5Posix
    \ matchgroup=p6RxP5Escape
    \ start="\[:"
    \ end=":]"
    \ contained
syn match p6RxP5Range      display contained "-"

" 'string' inside a regex
syn region p6RxStringSQ
    \ matchgroup=p6Quote
    \ start="'"
    \ skip="\\\@<!\\'"
    \ end="'"
    \ contained
    \ contains=p6EscQuote,p6EscBackSlash

" "string" inside a regex
syn region p6RxStringDQ
    \ matchgroup=p6Quote
    \ start=+"+
    \ skip=+\\\@<!\\"+
    \ end=+"+
    \ contained
    \ contains=p6EscDoubleQuote,p6EscBackSlash

" $!, $var, $!var, $::var, $package::var $*::package::var, etc
" Thus must come after the matches for the "$" regex anchor, but before
" the match for the $ regex delimiter
syn cluster p6Variables
    \ add=p6VarSlash
    \ add=p6VarExclam
    \ add=p6VarMatch
    \ add=p6VarNum
    \ add=p6Variable

syn match p6VarSlash     display "\$/"
syn match p6VarExclam    display "\$!"
syn match p6VarMatch     display "\$¢"
syn match p6VarNum       display "\$\d\+"
syn match p6Variable     display "\%(@@\|[@&$%]\$*\)\%(::\|\%(\%([.^*?=!~]\|:\@<!::\@!\)\K\)\|\K\)\@=" nextgroup=p6Twigil,p6VarName,p6PackageScope
syn match p6VarName      display "\K\%(\k\|[-']\K\@=\)*" contained
syn match p6Twigil       display "\%([.^*?=!~]\|:\@<!::\@!\)\K\@=" nextgroup=p6PackageScope,p6VarName contained
syn match p6PackageScope display "\%(\K\%(\k\|[-']\K\@=\)*\)\?::" nextgroup=p6PackageScope,p6VarName contained

" Perl 6 regex regions

" /foo/
" Below some hacks to recognise the // variant. This is virtually impossible
" to catch in all cases as the / is used in so many other ways, but these
" should be the most obvious ones.
" TODO: mostly stolen from perl.vim, might need more work
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\%(\<\%(split\|while\|until\|if\|unless\)\|\.\.\|[-+*!~(\[{=]\)\s*\)\@<=//\@!"
    \ start="^//\@!"
    \ start=+\s\@<=/[^[:space:][:digit:]$@%=]\@=\%(/\_s*\%([([{$@%&*[:digit:]"'`]\|\_s\w\|[[:upper:]_abd-fhjklnqrt-wyz]\)\)\@!/\@!+
    \ skip="\\/"
    \ end="/"
    \ contains=@p6Regexen,p6Variable,p6VarExclam,p6VarMatch,p6VarNum

" m/foo/, mm/foo/, rx/foo/
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<\%(mm\?\|rx\)\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<=//\@!"
    \ skip="\\/"
    \ end="/"
    \ keepend
    \ contains=@p6Regexen,p6Variable,p6VarExclam,p6VarMatch,p6VarNum

" m!foo!, mm!foo!, rx!foo!
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<\%(mm\?\|rx\)\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<=!!\@!"
    \ skip="\\!"
    \ end="!"
    \ keepend
    \ contains=@p6Regexen,p6Variable,p6VarSlash,p6VarMatch,p6VarNum

" m$foo$, mm$foo$, rx$foo$, m|foo|, mm|foo|, rx|foo|, etc
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<\%(mm\?\|rx\)\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<=\z([\"'`|,$]\)\$\@!"
    \ skip="\\\z1"
    \ end="\z1"
    \ keepend
    \ contains=@p6Regexen,@p6Variables

" m (foo), mm (foo), rx (foo)
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<\%(mm\?\|rx\)\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s\+\)\@<=()\@!)\@!"
    \ skip="\\)"
    \ end=")"
    \ contains=@p6Regexen,@p6Variables

" m[foo], mm[foo], rx[foo]
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<\%(mm\?\|rx\)\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<=\[]\@!]\@!"
    \ skip="\\]"
    \ end="]"
    \ contains=@p6Regexen,@p6Variables

" m{foo}, mm{foo}, rx{foo}
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<\%(mm\?\|rx\)\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<={}\@!}\@!"
    \ skip="\\}"
    \ end="}"
    \ contains=@p6Regexen,@p6Variables

" m<foo>, mm<foo>, rx<foo>
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<\%(mm\?\|rx\)\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<=<>\@!>\@!"
    \ skip="\\>"
    \ end=">"
    \ contains=@p6Regexen,@p6Variables

" m«foo», mm«foo», rx«foo»
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<\%(mm\?\|rx\)\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<=«»\@!»\@!"
    \ skip="\\»"
    \ end="»"
    \ contains=@p6Regexen,@p6Variables

" Substitutions

" s/foo/bar/
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<s\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<=/"
    \ skip="\\/"
    \ end="/"me=e-1
    \ keepend
    \ contains=@p6Regexen,p6Variable,p6VarExclam,p6VarMatch,p6VarNum
    \ nextgroup=p6Substitution

syn region p6Substitution
    \ matchgroup=p6Quote
    \ start="/"
    \ skip="\\/"
    \ end="/"
    \ contained
    \ keepend
    \ contains=@p6Interp_qq

" s!foo!bar!
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<s\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<=!"
    \ skip="\\!"
    \ end="!"me=e-1
    \ keepend
    \ contains=@p6Regexen,p6Variable,p6VarSlash,p6VarMatch,p6VarNum
    \ nextgroup=p6Substitution

syn region p6Substitution
    \ matchgroup=p6Quote
    \ start="!"
    \ skip="\\!"
    \ end="!"
    \ contained
    \ keepend
    \ contains=@p6Interp_qq

" s$foo$bar$, s|foo|bar, etc
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<s\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<=\z([\"'`|,$]\)"
    \ skip="\\\z1"
    \ end="\z1"me=e-1
    \ keepend
    \ contains=@p6Regexen,@p6Variables
    \ nextgroup=p6Substitution

syn region p6Substitution
    \ matchgroup=p6Quote
    \ start="\z([\"'`|,$]\)"
    \ skip="\\\z1"
    \ end="\z1"
    \ contained
    \ keepend
    \ contains=@p6Interp_qq

" s{foo}
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<s\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<={}\@!"
    \ skip="\\}"
    \ end="}"
    \ contains=@p6Regexen,@p6Variables

" s[foo]
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<s\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<=\[]\@!"
    \ skip="\\]"
    \ end="]"
    \ contains=@p6Regexen,@p6Variables

" s<foo>
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<s\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<=<>\@!"
    \ skip="\\>"
    \ end=">"
    \ contains=@p6Regexen,@p6Variables

" s«foo»
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<s\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<=«»\@!"
    \ skip="\\»"
    \ end="»"
    \ contains=@p6Regexen,@p6Variables

" s (foo)
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<s\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s\+\)\@<=()\@!"
    \ skip="\\)"
    \ end=")"
    \ contains=@p6Regexen,@p6Variables

" Perl 5 regex regions

" m:P5//
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<m\s*:P\%(erl\)\?5\s*\)\@<=/"
    \ skip="\\/"
    \ end="/"
    \ contains=@p6RegexP5,p6Variable,p6VarExclam,p6VarMatch,p6VarNum

" m:P5!!
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<m\s*:P\%(erl\)\?5\s*\)\@<=!"
    \ skip="\\!"
    \ end="!"
    \ contains=@p6RegexP5,p6Variable,p6VarSlash,p6VarMatch,p6VarNum

" m:P5$$, m:P5||, etc
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<m\s*:P\%(erl\)\?5\s*\)\@<=\z([\"'`|,$]\)"
    \ skip="\\\z1"
    \ end="\z1"
    \ contains=@p6RegexP5,@p6Variables

" m:P5 ()
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<m\s*:P\%(erl\)\?5\s\+\)\@<=()\@!"
    \ skip="\\)"
    \ end=")"
    \ contains=@p6RegexP5,@p6Variables

" m:P5[]
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<m\s*:P\%(erl\)\?5\s*\)\@<=[]\@!"
    \ skip="\\]"
    \ end="]"
    \ contains=@p6RegexP5,@p6Variables

" m:P5{}
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<m\s*:P\%(erl\)\?5\s*\)\@<={}\@!"
    \ skip="\\}"
    \ end="}"
    \ contains=@p6RegexP5,p6Variables

" m:P5<>
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<m\s*:P\%(erl\)\?5\s*\)\@<=<>\@!"
    \ skip="\\>"
    \ end=">"
    \ contains=@p6RegexP5,p6Variables

" m:P5«»
syn region p6Match
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<m\s*:P\%(erl\)\?5\s*\)\@<=«»\@!"
    \ skip="\\»"
    \ end="»"
    \ contains=@p6RegexP5,p6Variables

" Transliteration

" tr/foo/bar/, tr|foo|bar, etc
syn region p6String
    \ matchgroup=p6Quote
    \ start="\%(\%(::\|[$@%&][.!^:*?]\?\|\.\)\@<!\<tr\%(\s*:!\?\k\%(\k\|[-']\K\@=\)*\%(([^)]*)\)\?\)*\s*\)\@<=\z([/\"'`|!,$]\)"
    \ skip="\\\z1"
    \ end="\z1"me=e-1
    \ contains=p6RxRange
    \ nextgroup=p6Transliteration

syn region p6Transliteration
    \ matchgroup=p6Quote
    \ start="\z([/\"'`|!,$]\)"
    \ skip="\\\z1"
    \ end="\z1"
    \ contained
    \ contains=@p6Interp_qq

" Comments

" normal end-of-line comment
syn match p6Comment display "#.*" contains=p6Attention

" Multiline comments. Arbitrary numbers of opening brackets are allowed,
" but we only define regions for 1 to 3
syn region p6Comment
    \ matchgroup=p6Comment
    \ start="^\@<!#("
    \ skip="([^)]*)"
    \ end=")"
    \ matchgroup=p6Error
    \ start="^#("
    \ contains=p6Attention,p6Comment
syn region p6Comment
    \ matchgroup=p6Comment
    \ start="^\@<!#\["
    \ skip="\[[^\]]*]"
    \ end="]"
    \ matchgroup=p6Error
    \ start="^#\["
    \ contains=p6Attention,p6Comment
syn region p6Comment
    \ matchgroup=p6Comment
    \ start="^\@<!#{"
    \ skip="{[^}]*}"
    \ end="}"
    \ matchgroup=p6Error
    \ start="^#{"
    \ contains=p6Attention,p6Comment
syn region p6Comment
    \ matchgroup=p6Comment
    \ start="^\@<!#<"
    \ skip="<[^>]*>"
    \ end=">"
    \ matchgroup=p6Error
    \ start="^#<"
    \ contains=p6Attention,p6Comment
syn region p6Comment
    \ matchgroup=p6Comment
    \ start="^\@<!#«"
    \ skip="«[^»]*»"
    \ end="»"
    \ matchgroup=p6Error
    \ start="^#«"
    \ contains=p6Attention,p6Comment

" double and triple delimiters
if exists("perl6_extended_comments") || exists("perl6_extended_all")
    syn region p6Comment
        \ matchgroup=p6Comment
        \ start="^\@<!#(("
        \ skip="((\%([^)\|))\@!]\)*))"
        \ end="))"
        \ matchgroup=p6Error
        \ start="^#(("
        \ contains=p6Attention,p6Comment
    syn region p6Comment
        \ matchgroup=p6Comment
        \ start="^\@<!#((("
        \ skip="(((\%([^)]\|)\%())\)\@!\)*)))"
        \ end=")))"
        \ matchgroup=p6Error
        \ start="^#((("
        \ contains=p6Attention,p6Comment

    syn region p6Comment
        \ matchgroup=p6Comment
        \ start="^\@<!#\[\["
        \ skip="\[\[\%([^\]]\|]]\@!\)*]]"
        \ end="]]"
        \ matchgroup=p6Error
        \ start="^#\[\["
        \ contains=p6Attention,p6Comment
    syn region p6Comment
        \ matchgroup=p6Comment
        \ start="^\@<!#\[\[\["
        \ skip="\[\[\[\%([^\]]\|]\%(]]\)\@!\)*]]]"
        \ end="]]]"
        \ matchgroup=p6Error
        \ start="^#\[\[\["
        \ contains=p6Attention,p6Comment

    syn region p6Comment
        \ matchgroup=p6Comment
        \ start="^\@<!#{{"
        \ skip="{{\%([^}]\|}}\@!\)*}}"
        \ end="}}"
        \ matchgroup=p6Error
        \ start="^#{{"
        \ contains=p6Attention,p6Comment
    syn region p6Comment
        \ matchgroup=p6Comment
        \ start="^\@<!#{{{"
        \ skip="{{{\%([^}]\|}\%(}}\)\@!\)*}}}"
        \ end="}}}"
        \ matchgroup=p6Error
        \ start="^#{{{"
        \ contains=p6Attention,p6Comment

    syn region p6Comment
        \ matchgroup=p6Comment
        \ start="^\@<!#<<"
        \ skip="<<\%([^>]\|>>\@!\)*>>"
        \ end=">>"
        \ matchgroup=p6Error
        \ start="^#<<"
        \ contains=p6Attention,p6Comment
    syn region p6Comment
        \ matchgroup=p6Comment
        \ start="^\@<!#<<<"
        \ skip="<<<\%([^>]\|>\%(>>\)\@!\)*>>>"
        \ end=">>>"
        \ matchgroup=p6Error
        \ start="^#<<<"
        \ contains=p6Attention,p6Comment

    syn region p6Comment
        \ matchgroup=p6Comment
        \ start="^\@<!#««"
        \ skip="««\%([^»]\|»»\@!\)*»»"
        \ end="»»"
        \ matchgroup=p6Error
        \ start="^#««"
        \ contains=p6Attention,p6Comment
    syn region p6Comment
        \ matchgroup=p6Comment
        \ start="^\@<!#«««"
        \ skip="«««\%([^»]\|»\%(»»\)\@!\)*»»»"
        \ end="»»»"
        \ matchgroup=p6Error
        \ start="^#«««"
        \ contains=p6Attention,p6Comment
endif

" Pod

" Abbreviated blocks (implicit code forbidden)
syn region p6PodAbbrRegion
    \ matchgroup=p6PodPrefix
    \ start="^=\ze\K\k*"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contains=p6PodAbbrNoCodeType
    \ keepend

syn region p6PodAbbrNoCodeType
    \ matchgroup=p6PodType
    \ start="\K\k*"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contained
    \ contains=p6PodName,p6PodAbbrNoCode

syn match p6PodName contained ".\+" contains=@p6PodFormat
syn match p6PodComment contained ".\+"

syn region p6PodAbbrNoCode
    \ start="^"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contained
    \ contains=@p6PodFormat

" Abbreviated blocks (everything is code)
syn region p6PodAbbrRegion
    \ matchgroup=p6PodPrefix
    \ start="^=\zecode\>"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contains=p6PodAbbrCodeType
    \ keepend

syn region p6PodAbbrCodeType
    \ matchgroup=p6PodType
    \ start="\K\k*"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contained
    \ contains=p6PodName,p6PodAbbrCode

syn region p6PodAbbrCode
    \ start="^"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contained

" Abbreviated blocks (everything is a comment)
syn region p6PodAbbrRegion
    \ matchgroup=p6PodPrefix
    \ start="^=\zecomment\>"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contains=p6PodAbbrCommentType
    \ keepend

syn region p6PodAbbrCommentType
    \ matchgroup=p6PodType
    \ start="\K\k*"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contained
    \ contains=p6PodComment,p6PodAbbrNoCode

" Abbreviated blocks (implicit code allowed)
syn region p6PodAbbrRegion
    \ matchgroup=p6PodPrefix
    \ start="^=\ze\%(pod\|item\|nested\|\u\+\)\>"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contains=p6PodAbbrType
    \ keepend

syn region p6PodAbbrType
    \ matchgroup=p6PodType
    \ start="\K\k*"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contained
    \ contains=p6PodName,p6PodAbbr

syn region p6PodAbbr
    \ start="^"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contained
    \ contains=@p6PodFormat,p6PodImplicitCode

" Abbreviated block to end-of-file
syn region p6PodAbbrRegion
    \ matchgroup=p6PodPrefix
    \ start="^=\zeEND\>"
    \ end="\%$"
    \ contains=p6PodAbbrEOFType
    \ keepend

syn region p6PodAbbrEOFType
    \ matchgroup=p6PodType
    \ start="\K\k*"
    \ end="\%$"
    \ contained
    \ contains=p6PodName,p6PodAbbrEOF

syn region p6PodAbbrEOF
    \ start="^"
    \ end="\%$"
    \ contained
    \ contains=@p6PodNestedBlocks,@p6PodFormat,p6PodImplicitCode

" Directives
syn region p6PodDirectRegion
    \ matchgroup=p6PodPrefix
    \ start="^=\%(config\|use\)\>"
    \ end="^\ze\%([^=]\|=\K\|\s*$\)"
    \ contains=p6PodDirectArgRegion
    \ keepend

syn region p6PodDirectArgRegion
    \ matchgroup=p6PodType
    \ start="\S\+"
    \ end="^\ze\%([^=]\|=\K\|\s*$\)"
    \ contained
    \ contains=p6PodDirectConfigRegion

syn region p6PodDirectConfigRegion
    \ start=""
    \ end="^\ze\%([^=]\|=\K\|\s*$\)"
    \ contained
    \ contains=@p6PodConfig

" =encoding is a special directive
syn region p6PodDirectRegion
    \ matchgroup=p6PodPrefix
    \ start="^=encoding\>"
    \ end="^\ze\%([^=]\|=\K\|\s*$\)"
    \ contains=p6PodEncodingArgRegion
    \ keepend

syn region p6PodEncodingArgRegion
    \ matchgroup=p6PodName
    \ start="\S\+"
    \ end="^\ze\%([^=]\|=\K\|\s*$\)"
    \ contained

" Paragraph blocks (implicit code forbidden)
syn region p6PodParaRegion
    \ matchgroup=p6PodPrefix
    \ start="^=for\>"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contains=p6PodParaNoCodeTypeRegion
    \ keepend
    \ extend

syn region p6PodParaNoCodeTypeRegion
    \ matchgroup=p6PodType
    \ start="\K\k*"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contained
    \ contains=p6PodParaNoCode,p6PodParaConfigRegion

syn region p6PodParaConfigRegion
    \ start=""
    \ end="^\ze\%([^=]\|=\k\@<!\)"
    \ contained
    \ contains=@p6PodConfig

syn region p6PodParaNoCode
    \ start="^[^=]"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contained
    \ contains=@p6PodFormat

" Paragraph blocks (everything is code)
syn region p6PodParaRegion
    \ matchgroup=p6PodPrefix
    \ start="^=for\>\ze\s*code\>"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contains=p6PodParaCodeTypeRegion
    \ keepend
    \ extend

syn region p6PodParaCodeTypeRegion
    \ matchgroup=p6PodType
    \ start="\K\k*"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contained
    \ contains=p6PodParaCode,p6PodParaConfigRegion

syn region p6PodParaCode
    \ start="^[^=]"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contained

" Paragraph blocks (implicit code allowed)
syn region p6PodParaRegion
    \ matchgroup=p6PodPrefix
    \ start="^=for\>\ze\s*\%(pod\|item\|nested\|\u\+\)\>"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contains=p6PodParaTypeRegion
    \ keepend
    \ extend

syn region p6PodParaTypeRegion
    \ matchgroup=p6PodType
    \ start="\K\k*"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contained
    \ contains=p6PodPara,p6PodParaConfigRegion

syn region p6PodPara
    \ start="^[^=]"
    \ end="^\ze\%(\s*$\|=\K\)"
    \ contained
    \ contains=@p6PodFormat,p6PodImplicitCode

" Paragraph block to end-of-file
syn region p6PodParaRegion
    \ matchgroup=p6PodPrefix
    \ start="^=for\>\ze\s\+END\>"
    \ end="\%$"
    \ contains=p6PodParaEOFTypeRegion
    \ keepend
    \ extend

syn region p6PodParaEOFTypeRegion
    \ matchgroup=p6PodType
    \ start="\K\k*"
    \ end="\%$"
    \ contained
    \ contains=p6PodParaEOF,p6PodParaConfigRegion

syn region p6PodParaEOF
    \ start="^[^=]"
    \ end="\%$"
    \ contained
    \ contains=@p6PodNestedBlocks,@p6PodFormat,p6PodImplicitCode

" Delimited blocks (implicit code forbidden)
syn region p6PodDelimRegion
    \ matchgroup=p6PodPrefix
    \ start="^=begin\>"
    \ end="^=end\>"
    \ contains=p6PodDelimNoCodeTypeRegion
    \ keepend
    \ extend

syn region p6PodDelimNoCodeTypeRegion
    \ matchgroup=p6PodType
    \ start="\K\k*"
    \ end="^\ze=end\>"
    \ contained
    \ contains=p6PodDelimNoCode,p6PodDelimConfigRegion

syn region p6PodDelimConfigRegion
    \ start=""
    \ end="^\ze\%([^=]\|=\K\|\s*$\)"
    \ contained
    \ contains=@p6PodConfig

syn region p6PodDelimNoCode
    \ start="^"
    \ end="^\ze=end\>"
    \ contained
    \ contains=@p6PodNestedBlocks,@p6PodFormat

" Delimited blocks (everything is code)
syn region p6PodDelimRegion
    \ matchgroup=p6PodPrefix
    \ start="^=begin\>\ze\s*code\>"
    \ end="^=end\>"
    \ contains=p6PodDelimCodeTypeRegion
    \ keepend
    \ extend

syn region p6PodDelimCodeTypeRegion
    \ matchgroup=p6PodType
    \ start="\K\k*"
    \ end="^\ze=end\>"
    \ contained
    \ contains=p6PodDelimCode,p6PodDelimConfigRegion

syn region p6PodDelimCode
    \ start="^"
    \ end="^\ze=end\>"
    \ contained
    \ contains=@p6PodNestedBlocks

" Delimited blocks (implicit code allowed)
syn region p6PodDelimRegion
    \ matchgroup=p6PodPrefix
    \ start="^=begin\>\ze\s*\%(pod\|item\|nested\|\u\+\)\>"
    \ end="^=end\>"
    \ contains=p6PodDelimTypeRegion
    \ keepend
    \ extend

syn region p6PodDelimTypeRegion
    \ matchgroup=p6PodType
    \ start="\K\k*"
    \ end="^\ze=end\>"
    \ contained
    \ contains=p6PodDelim,p6PodDelimConfigRegion

syn region p6PodDelim
    \ start="^"
    \ end="^\ze=end\>"
    \ contained
    \ contains=@p6PodNestedBlocks,@p6PodFormat,p6PodImplicitCode

" Delimited block to end-of-file
syn region p6PodDelimRegion
    \ matchgroup=p6PodPrefix
    \ start="^=begin\>\ze\s\+END\>"
    \ end="\%$"
    \ contains=p6PodDelimEOFTypeRegion
    \ extend

syn region p6PodDelimEOFTypeRegion
    \ matchgroup=p6PodType
    \ start="\K\k*"
    \ end="\%$"
    \ contained
    \ contains=p6PodDelimEOF,p6PodDelimConfigRegion

syn region p6PodDelimEOF
    \ start="^"
    \ end="\%$"
    \ contained
    \ contains=@p6PodNestedBlocks,@p6PodFormat,p6PodImplicitCode

syn cluster p6PodConfig
    \ add=p6PodConfigOperator
    \ add=p6PodExtraConfig
    \ add=p6StringAuto
    \ add=p6PodAutoQuote
    \ add=p6StringSQ

syn region p6PodParens
    \ start="("
    \ end=")"
    \ contained
    \ contains=p6Number,p6StringSQ

syn match p6PodAutoQuote      display contained "=>"
syn match p6PodConfigOperator display contained ":!\?" nextgroup=p6PodConfigOption
syn match p6PodConfigOption   display contained "[^[:space:](<]\+" nextgroup=p6PodParens,p6StringAngle
syn match p6PodExtraConfig    display contained "^="
syn match p6PodVerticalBar    display contained "|"
syn match p6PodColon          display contained ":"
syn match p6PodSemicolon      display contained ";"
syn match p6PodComma          display contained ","
syn match p6PodImplicitCode   display contained "^\s.*"

syn region p6PodDelimEndRegion
    \ matchgroup=p6PodType
    \ start="\%(^=end\>\)\@<="
    \ end="\K\k*"

" These may appear inside delimited blocks
syn cluster p6PodNestedBlocks
    \ add=p6PodAbbrRegion
    \ add=p6PodDirectRegion
    \ add=p6PodParaRegion
    \ add=p6PodDelimRegion
    \ add=p6PodDelimEndRegion

" Pod formatting codes

syn cluster p6PodFormat
    \ add=p6PodFormatOne
    \ add=p6PodFormatTwo
    \ add=p6PodFormatThree
    \ add=p6PodFormatFrench

" Balanced angles found inside formatting codes. Ensures proper nesting.

syn region p6PodFormatAnglesOne
    \ matchgroup=p6PodFormat
    \ start="<"
    \ skip="<[^>]*>"
    \ end=">"
    \ transparent
    \ contained
    \ contains=p6PodFormatAnglesFrench,p6PodFormatAnglesOne

syn region p6PodFormatAnglesTwo
    \ matchgroup=p6PodFormat
    \ start="<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ transparent
    \ contained
    \ contains=p6PodFormatAnglesFrench,p6PodFormatAnglesOne,p6PodFormatAnglesTwo

syn region p6PodFormatAnglesThree
    \ matchgroup=p6PodFormat
    \ start="<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ transparent
    \ contained
    \ contains=p6PodFormatAnglesFrench,p6PodFormatAnglesOne,p6PodFormatAnglesTwo,p6PodFormatAnglesThree

syn region p6PodFormatAnglesFrench
    \ matchgroup=p6PodFormat
    \ start="«"
    \ skip="«[^»]*»"
    \ end="»"
    \ transparent
    \ contained
    \ contains=p6PodFormatAnglesFrench,p6PodFormatAnglesOne,p6PodFormatAnglesTwo,p6PodFormatAnglesThree

" All formatting codes

syn region p6PodFormatOne
    \ matchgroup=p6PodFormatCode
    \ start="\u<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=p6PodFormatAnglesOne,p6PodFormatFrench,p6PodFormatOne

syn region p6PodFormatTwo
    \ matchgroup=p6PodFormatCode
    \ start="\u<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=p6PodFormatAnglesTwo,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo

syn region p6PodFormatThree
    \ matchgroup=p6PodFormatCode
    \ start="\u<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=p6PodFormatAnglesThree,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodFormatThree

syn region p6PodFormatFrench
    \ matchgroup=p6PodFormatCode
    \ start="\u«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=p6PodFormatAnglesFrench,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodFormatThree

" C<> and V<> don't allow nested formatting formatting codes

syn region p6PodFormatOne
    \ matchgroup=p6PodFormatCode
    \ start="[CV]<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=p6PodFormatAnglesOne

syn region p6PodFormatTwo
    \ matchgroup=p6PodFormatCode
    \ start="[CV]<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=p6PodFormatAnglesTwo

syn region p6PodFormatThree
    \ matchgroup=p6PodFormatCode
    \ start="[CV]<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=p6PodFormatAnglesThree

syn region p6PodFormatFrench
    \ matchgroup=p6PodFormatCode
    \ start="[CV]«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=p6PodFormatAnglesFrench

" L<> can have a "|" separator

syn region p6PodFormatOne
    \ matchgroup=p6PodFormatCode
    \ start="L<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=p6PodFormatAnglesOne,p6PodFormatFrench,p6PodFormatOne,p6PodVerticalBar

syn region p6PodFormatTwo
    \ matchgroup=p6PodFormatCode
    \ start="L<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=p6PodFormatAnglesTwo,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodVerticalBar

syn region p6PodFormatThree
    \ matchgroup=p6PodFormatCode
    \ start="L<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=p6PodFormatAnglesThree,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodFormatThree,p6PodVerticalBar

syn region p6PodFormatFrench
    \ matchgroup=p6PodFormatCode
    \ start="L«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=p6PodFormatAnglesFrench,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodFormatThree,p6PodVerticalBar

" E<> can have a ";" separator

syn region p6PodFormatOne
    \ matchgroup=p6PodFormatCode
    \ start="E<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=p6PodFormatAnglesOne,p6PodFormatFrench,p6PodFormatOne,p6PodSemiColon

syn region p6PodFormatTwo
    \ matchgroup=p6PodFormatCode
    \ start="E<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=p6PodFormatAnglesTwo,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodSemiColon

syn region p6PodFormatThree
    \ matchgroup=p6PodFormatCode
    \ start="E<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=p6PodFormatAnglesThree,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodFormatThree,p6PodSemiColon

syn region p6PodFormatFrench
    \ matchgroup=p6PodFormatCode
    \ start="E«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=p6PodFormatAnglesFrench,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodFormatThree,p6PodSemiColon

" M<> can have a ":" separator

syn region p6PodFormatOne
    \ matchgroup=p6PodFormatCode
    \ start="M<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=p6PodFormatAnglesOne,p6PodFormatFrench,p6PodFormatOne,p6PodColon

syn region p6PodFormatTwo
    \ matchgroup=p6PodFormatCode
    \ start="M<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=p6PodFormatAnglesTwo,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodColon

syn region p6PodFormatThree
    \ matchgroup=p6PodFormatCode
    \ start="M<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=p6PodFormatAnglesThree,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodFormatThree,p6PodColon

syn region p6PodFormatFrench
    \ matchgroup=p6PodFormatCode
    \ start="M«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=p6PodFormatAnglesFrench,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodFormatThree,p6PodColon

" D<> can have "|" and ";" separators

syn region p6PodFormatOne
    \ matchgroup=p6PodFormatCode
    \ start="D<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=p6PodFormatAnglesOne,p6PodFormatFrench,p6PodFormatOne,p6PodVerticalBar,p6PodSemiColon

syn region p6PodFormatTwo
    \ matchgroup=p6PodFormatCode
    \ start="D<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=p6PodFormatAngleTwo,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodVerticalBar,p6PodSemiColon

syn region p6PodFormatThree
    \ matchgroup=p6PodFormatCode
    \ start="D<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=p6PodFormatAnglesThree,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodFormatThree,p6PodVerticalBar,p6PodSemiColon

syn region p6PodFormatFrench
    \ matchgroup=p6PodFormatCode
    \ start="D«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=p6PodFormatAnglesFrench,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodFormatThree,p6PodVerticalBar,p6PodSemiColon

" X<> can have "|", "," and ";" separators

syn region p6PodFormatOne
    \ matchgroup=p6PodFormatCode
    \ start="X<"
    \ skip="<[^>]*>"
    \ end=">"
    \ contained
    \ contains=p6PodFormatAnglesOne,p6PodFormatFrench,p6PodFormatOne,p6PodVerticalBar,p6PodSemiColon,p6PodComma

syn region p6PodFormatTwo
    \ matchgroup=p6PodFormatCode
    \ start="X<<"
    \ skip="<<[^>]*>>"
    \ end=">>"
    \ contained
    \ contains=p6PodFormatAnglesTwo,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodVerticalBar,p6PodSemiColon,p6PodComma

syn region p6PodFormatThree
    \ matchgroup=p6PodFormatCode
    \ start="X<<<"
    \ skip="<<<[^>]*>>>"
    \ end=">>>"
    \ contained
    \ contains=p6PodFormatAnglesThree,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodFormatThree,p6PodVerticalBar,p6PodSemiColon,p6PodComma

syn region p6PodFormatFrench
    \ matchgroup=p6PodFormatCode
    \ start="X«"
    \ skip="«[^»]*»"
    \ end="»"
    \ contained
    \ contains=p6PodFormatAnglesFrench,p6PodFormatFrench,p6PodFormatOne,p6PodFormatTwo,p6PodFormatThree,p6PodVerticalBar,p6PodSemiColon,p6PodComma

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_perl6_syntax_inits")
    if version < 508
        let did_perl6_syntax_inits = 1
        command -nargs=+ HiLink hi link <args>
    else
        command -nargs=+ HiLink hi def link <args>
    endif

    HiLink p6EscOctOld       p6Error
    HiLink p6PackageTwigil   p6Twigil
    HiLink p6StringAngle     p6String
    HiLink p6StringFrench    p6String
    HiLink p6StringAngles    p6String
    HiLink p6StringSQ        p6String
    HiLink p6StringDQ        p6String
    HiLink p6StringQ         p6String
    HiLink p6RxStringSQ      p6String
    HiLink p6RxStringDQ      p6String
    HiLink p6Substitution    p6String
    HiLink p6Transliteration p6String
    HiLink p6StringAuto      p6String
    HiLink p6StringP5Auto    p6String
    HiLink p6Key             p6String
    HiLink p6Match           p6String
    HiLink p6RegexBlock      p6String
    HiLink p6RxP5CharClass   p6String
    HiLink p6RxP5QuoteMeta   p6String
    HiLink p6RxCharClass     p6String
    HiLink p6RxQuoteWords    p6String
    HiLink p6ReduceOp        p6Operator
    HiLink p6ReverseCrossOp  p6Operator
    HiLink p6HyperOp         p6Operator
    HiLink p6QuoteQ          p6Operator
    HiLink p6RxRange         p6StringSpecial
    HiLink p6RxAnchor        p6StringSpecial
    HiLink p6RxP5Anchor      p6StringSpecial
    HiLink p6CodePoint       p6StringSpecial
    HiLink p6RxMeta          p6StringSpecial
    HiLink p6RxP5Range       p6StringSpecial
    HiLink p6RxP5CPId        p6StringSpecial
    HiLink p6RxP5Posix       p6StringSpecial
    HiLink p6RxP5Mod         p6StringSpecial
    HiLink p6RxP5HexSeq      p6StringSpecial
    HiLink p6RxP5OctSeq      p6StringSpecial
    HiLink p6RxP5WriteRefId  p6StringSpecial
    HiLink p6HexSequence     p6StringSpecial
    HiLink p6OctSequence     p6StringSpecial
    HiLink p6RxP5Named       p6StringSpecial
    HiLink p6RxP5PropId      p6StringSpecial
    HiLink p6RxP5Quantifier  p6StringSpecial
    HiLink p6RxP5CountId     p6StringSpecial
    HiLink p6RxP5Verb        p6StringSpecial
    HiLink p6Escape          p6StringSpecial2
    HiLink p6EscNull         p6StringSpecial2
    HiLink p6EscHash         p6StringSpecial2
    HiLink p6EscQQ           p6StringSpecial2
    HiLink p6EscQuote        p6StringSpecial2
    HiLink p6EscDoubleQuote  p6StringSpecial2
    HiLink p6EscBackTick     p6StringSpecial2
    HiLink p6EscForwardSlash p6StringSpecial2
    HiLink p6EscVerticalBar  p6StringSpecial2
    HiLink p6EscExclamation  p6StringSpecial2
    HiLink p6EscDollar       p6StringSpecial2
    HiLink p6EscOpenCurly    p6StringSpecial2
    HiLink p6EscCloseCurly   p6StringSpecial2
    HiLink p6EscCloseBracket p6StringSpecial2
    HiLink p6EscCloseAngle   p6StringSpecial2
    HiLink p6EscCloseFrench  p6StringSpecial2
    HiLink p6EscBackSlash    p6StringSpecial2
    HiLink p6RxEscape        p6StringSpecial2
    HiLink p6RxCapture       p6StringSpecial2
    HiLink p6RxAlternation   p6StringSpecial2
    HiLink p6RxP5            p6StringSpecial2
    HiLink p6RxP5ReadRef     p6StringSpecial2
    HiLink p6RxP5Oct         p6StringSpecial2
    HiLink p6RxP5Hex         p6StringSpecial2
    HiLink p6RxP5EscMeta     p6StringSpecial2
    HiLink p6RxP5Meta        p6StringSpecial2
    HiLink p6RxP5Escape      p6StringSpecial2
    HiLink p6RxP5CodePoint   p6StringSpecial2
    HiLink p6RxP5WriteRef    p6StringSpecial2
    HiLink p6RxP5Prop        p6StringSpecial2

    HiLink p6Property       Tag
    HiLink p6Attention      Todo
    HiLink p6Type           Type
    HiLink p6Error          Error
    HiLink p6BlockLabel     Label
    HiLink p6Float          Float
    HiLink p6Normal         Normal
    HiLink p6Package        Normal
    HiLink p6PackageScope   Normal
    HiLink p6Number         Number
    HiLink p6VersionNum     Number
    HiLink p6String         String
    HiLink p6Repeat         Repeat
    HiLink p6Keyword        Keyword
    HiLink p6Pragma         Keyword
    HiLink p6Module         Keyword
    HiLink p6DeclareRoutine Keyword
    HiLink p6VarStorage     Special
    HiLink p6FlowControl    Special
    HiLink p6NumberBase     Special
    HiLink p6Twigil         Special
    HiLink p6StringSpecial2 Special
    HiLink p6VersionDot     Special
    HiLink p6Comment        Comment
    HiLink p6Include        Include
    HiLink p6Shebang        PreProc
    HiLink p6ClosureTrait   PreProc
    HiLink p6Routine        Function
    HiLink p6Operator       Operator
    HiLink p6Version        Operator
    HiLink p6Context        Operator
    HiLink p6Quote          Delimiter
    HiLink p6TypeConstraint PreCondit
    HiLink p6Exception      Exception
    HiLink p6Placeholder    Identifier
    HiLink p6Variable       Identifier
    HiLink p6VarSlash       Identifier
    HiLink p6VarNum         Identifier
    HiLink p6VarExclam      Identifier
    HiLink p6VarMatch       Identifier
    HiLink p6VarName        Identifier
    HiLink p6MatchVar       Identifier
    HiLink p6RxP5ReadRefId  Identifier
    HiLink p6RxP5ModDef     Identifier
    HiLink p6RxP5ModName    Identifier
    HiLink p6Conditional    Conditional
    HiLink p6StringSpecial  SpecialChar

    HiLink p6PodAbbr         p6Pod
    HiLink p6PodAbbrEOF      p6Pod
    HiLink p6PodAbbrNoCode   p6Pod
    HiLink p6PodAbbrCode     p6PodCode
    HiLink p6PodPara         p6Pod
    HiLink p6PodParaEOF      p6Pod
    HiLink p6PodParaNoCode   p6Pod
    HiLink p6PodParaCode     p6PodCode
    HiLink p6PodDelim        p6Pod
    HiLink p6PodDelimEOF     p6Pod
    HiLink p6PodDelimNoCode  p6Pod
    HiLink p6PodDelimCode    p6PodCode
    HiLink p6PodImplicitCode p6PodCode
    HiLink p6PodExtraConfig  p6PodPrefix
    HiLink p6PodVerticalBar  p6PodFormatCode
    HiLink p6PodColon        p6PodFormatCode
    HiLink p6PodSemicolon    p6PodFormatCode
    HiLink p6PodComma        p6PodFormatCode
    HiLink p6PodFormatOne    p6PodFormat
    HiLink p6PodFormatTwo    p6PodFormat
    HiLink p6PodFormatThree  p6PodFormat
    HiLink p6PodFormatFrench p6PodFormat

    HiLink p6PodType           Type
    HiLink p6PodConfigOption   String
    HiLink p6PodCode           PreProc
    HiLink p6Pod               Comment
    HiLink p6PodComment        Comment
    HiLink p6PodAutoQuote      Operator
    HiLink p6PodConfigOperator Operator
    HiLink p6PodPrefix         Statement
    HiLink p6PodName           Identifier
    HiLink p6PodFormatCode     SpecialChar
    HiLink p6PodFormat         SpecialComment

    delcommand HiLink
endif

" Syncing to speed up processing
"syn sync match p6SyncPod groupthere p6PodAbbrRegion     "^=\K\k*\>"
"syn sync match p6SyncPod groupthere p6PodDirectRegion   "^=\%(config\|use\|encoding\)\>"
"syn sync match p6SyncPod groupthere p6PodParaRegion     "^=for\>"
"syn sync match p6SyncPod groupthere p6PodDelimRegion    "^=begin\>"
"syn sync match p6SyncPod groupthere p6PodDelimEndRegion "^=end\>"

" Let's just sync whole file, the other methods aren't reliable (or I don't
" know how to use them reliably)
syn sync fromstart

setlocal foldmethod=syntax

let b:current_syntax = "perl6"

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:ts=8:sts=4:sw=4:expandtab:ft=vim
