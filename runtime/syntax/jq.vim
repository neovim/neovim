" Vim compiler file
" Language:	jq
" Maintainer:	Vito <vito.blog@gmail.com>
" Last Change:	2024 Apr 17
" Upstream: https://github.com/vito-c/jq.vim
"
" Quit when a (custom) syntax file was already loaded
if exists('b:current_syntax')
  finish
endif

" syn include @jqHtml syntax/html.vim  " Doc comment HTML

" jqTodo
syntax keyword jqTodo contained TODO FIXME NOTE XXX

" jqKeywords
syntax keyword jqKeywords and or not empty
syntax keyword jqKeywords try catch
syntax keyword jqKeywords reduce as label break foreach
syntax keyword jqKeywords import include module modulemeta
syntax keyword jqKeywords env nth has in while error stderr debug

" jqConditional
syntax keyword jqConditional if then elif else end

" jqConditions
syntax keyword jqCondtions true false null

" jqSpecials
syntax keyword jqType type
syntax match jqType /[\|;]/ " not really a type I did this for coloring reasons though :help group-name
syntax region jqParentheses start=+(+ end=+)+ fold transparent

" jq Functions
syntax keyword jqFunction add all any arrays ascii_downcase floor
syntax keyword jqFunction ascii_upcase booleans bsearch builtins capture combinations
syntax keyword jqFunction \contains del delpaths endswith explode
syntax keyword jqFunction finites first flatten format from_entries
syntax keyword jqFunction fromdate fromdateiso8601 fromjson fromstream get_jq_origin
syntax keyword jqFunction get_prog_origin get_search_list getpath gmtime group_by
syntax keyword jqFunction gsub halt halt_error implode index indices infinite
syntax keyword jqFunction input input_filename input_line_number inputs inside
syntax keyword jqFunction isempty isfinite isinfinite isnan isnormal iterables
syntax keyword jqFunction join keys keys_unsorted last leaf_paths
syntax keyword jqFunction length limit localtime ltrimstr map map_values
syntax keyword jqFunction match max max_by min min_by
syntax keyword jqFunction mktime nan normals now
syntax keyword jqFunction nulls numbers objects path paths range
syntax keyword jqFunction recurse recurse_down repeat reverse rindex
syntax keyword jqFunction rtrimstr scalars scalars_or_empty scan select
syntax keyword jqFunction setpath sort sort_by split splits with_entries
syntax keyword jqFunction startswith strflocaltime strftime strings strptime sub
syntax keyword jqFunction test to_entries todate todateiso8601 tojson __loc__
syntax keyword jqFunction tonumber tostream tostring transpose truncate_stream
syntax keyword jqFunction unique unique_by until utf8bytelength values walk
" TODO: $__loc__ is going to be a pain

" jq Math Functions
syntax keyword jqFunction acos acosh asin asinh atan atanh cbrt ceil cos cosh
syntax keyword jqFunction erf erfc exp exp10 exp2 expm1 fabs floor gamma j0 j1
syntax keyword jqFunction lgamma lgamma_r log log10 log1p log2 logb nearbyint
syntax keyword jqFunction pow10 rint round significand sin sinh sqrt tan tanh
syntax keyword jqFunction tgamma trunc y0 y1
syntax keyword jqFunction atan2 copysign drem fdim fmax fmin fmod frexp hypot
syntax keyword jqFunction jn ldexp modf nextafter nexttoward pow remainder
syntax keyword jqFunction scalb scalbln yn
syntax keyword jqFunction fma

" jq SQL-style Operators
syntax keyword jqFunction INDEX JOIN IN

" Macro
syntax match jqMacro "@\%(text\|json\|html\|uri\|[ct]sv\|sh\|base64d\?\)\>"

" Comments
syntax match jqComment "#.*" contains=jqTodo

" Variables
syn match jqVariables /$[_A-Za-z0-9]\+/

" Definition
syntax keyword jqKeywords def nextgroup=jqNameDefinition skipwhite
syn match jqNameDefinition /\<[_A-Za-z0-9]\+\>/ contained nextgroup=jqPostNameDefinition
syn match jqNameDefinition /`[^`]\+`/ contained nextgroup=jqPostNameDefinition

" Strings
syn region jqError start=+'+ end=+'\|$\|[;)]\@=+
syn region jqString matchgroup=jqQuote
            \ start=+"+ skip=+\\[\\"]+ end=+"+
            \ contains=@Spell,jqInterpolation
syn region jqInterpolation matchgroup=jqInterpolationDelimiter
            \ start=+\%([^\\]\%(\\\\\)*\\\)\@<!\\(+ end=+)+
            \ contained contains=TOP

" Operators
syn match jqOperator /:\|\([-+*/%<>=]\|\/\/\)=\?\|[!|]=\|?\/\//
"syn region jqRange matchgroup=jqSquareBracket start=+\[+ skip=+:+ end=+\]+

" Errors
syn keyword jqError _assign _flatten _modify _nwise _plus _negate _minus _multiply
syn keyword jqError _divide _mod _strindices _equal _notequal _less _greater _lesseq
syn keyword jqError _greatereq _sort_by_impl _group_by_impl _min_by_impl _max_by_impl _match_impl _input
" TODO: these errors should show up when doing def _flatten: as well

" Numbers
syn match jqNumber /\<0[dDfFlL]\?\>/ " Just a bare 0
syn match jqNumber /\<[1-9]\d*[dDfFlL]\?\>/  " A multi-digit number - octal numbers with leading 0's are deprecated in Scala

if !exists('jq_quote_highlight')
    highlight def link jqQuote        String
else
    highlight def link jqQuote        Type
endif

hi def link jqCondtions              Boolean
hi def link jqVariables              Identifier
hi def link jqNameDefinition         Function
hi def link jqTodo                   Todo
hi def link jqComment                Comment
hi def link jqKeywords               Keyword
hi def link jqType                   Type
hi def link jqOperator               Operator
hi def link jqFunction               Function
hi def link jqMacro                  Macro
hi def link jqError                  Error
hi def link jqString                 String
hi def link jqInterpolationDelimiter Delimiter
hi def link jqConditional            Conditional
hi def link jqNumber                 Number
