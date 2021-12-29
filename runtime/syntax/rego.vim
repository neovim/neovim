" Vim syntax file
" Language: rego policy language
" Maintainer: Matt Dunford (zenmatic@gmail.com)
" URL:        https://github.com/zenmatic/vim-syntax-rego
" Last Change: 2019 Dec 12

" https://www.openpolicyagent.org/docs/latest/policy-language/

" quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

syn case match

syn keyword regoDirective package import allow deny
syn keyword regoKeywords as default else false not null true with some

syn keyword regoFuncAggregates count sum product max min sort all any
syn match regoFuncArrays "\<array\.\(concat\|slice\)\>"
syn keyword regoFuncSets intersection union

syn keyword regoFuncStrings concat /\<contains\>/ endswith format_int indexof lower replace split sprintf startswith substring trim trim_left trim_prefix trim_right trim_suffix trim_space upper
syn match regoFuncStrings2 "\<strings\.replace_n\>"
syn match regoFuncStrings3 "\<contains\>"

syn keyword regoFuncRegex re_match
syn match regoFuncRegex2 "\<regex\.\(split\|globs_match\|template_match\|find_n\|find_all_string_submatch_n\)\>"

syn match regoFuncGlob "\<glob\.\(match\|quote_meta\)\>"
syn match regoFuncUnits "\<units\.parse_bytes\>"
syn keyword regoFuncTypes is_number is_string is_boolean is_array is_set is_object is_null type_name
syn match regoFuncEncoding1 "\<\(base64\|base64url\)\.\(encode\|decode\)\>"
syn match regoFuncEncoding2 "\<urlquery\.\(encode\|decode\|encode_object\)\>"
syn match regoFuncEncoding3 "\<\(json\|yaml\)\.\(marshal\|unmarshal\)\>"
syn match regoFuncTokenSigning "\<io\.jwt\.\(encode_sign_raw\|encode_sign\)\>"
syn match regoFuncTokenVerification "\<io\.jwt\.\(verify_rs256\|verify_ps256\|verify_es256\|verify_hs256\|decode\|decode_verify\)\>"
syn match regoFuncTime "\<time\.\(now_ns\|parse_ns\|parse_rfc3339_ns\|parse_duration_ns\|date\|clock\|weekday\)\>"
syn match regoFuncCryptography "\<crypto\.x509\.parse_certificates\>"
syn keyword regoFuncGraphs walk
syn match regoFuncHttp "\<http\.send\>"
syn match regoFuncNet "\<net\.\(cidr_contains\|cidr_intersects\)\>"
syn match regoFuncRego "\<rego\.parse_module\>"
syn match regoFuncOpa "\<opa\.runtime\>"
syn keyword regoFuncDebugging trace

hi def link regoDirective Statement
hi def link regoKeywords Statement
hi def link regoFuncAggregates Statement
hi def link regoFuncArrays Statement
hi def link regoFuncSets Statement
hi def link regoFuncStrings Statement
hi def link regoFuncStrings2 Statement
hi def link regoFuncStrings3 Statement
hi def link regoFuncRegex Statement
hi def link regoFuncRegex2 Statement
hi def link regoFuncGlob Statement
hi def link regoFuncUnits Statement
hi def link regoFuncTypes Statement
hi def link regoFuncEncoding1 Statement
hi def link regoFuncEncoding2 Statement
hi def link regoFuncEncoding3 Statement
hi def link regoFuncTokenSigning Statement
hi def link regoFuncTokenVerification Statement
hi def link regoFuncTime Statement
hi def link regoFuncCryptography Statement
hi def link regoFuncGraphs Statement
hi def link regoFuncHttp Statement
hi def link regoFuncNet Statement
hi def link regoFuncRego Statement
hi def link regoFuncOpa Statement
hi def link regoFuncDebugging Statement

" https://www.openpolicyagent.org/docs/latest/policy-language/#strings
syn region      regoString            start=+"+ skip=+\\\\\|\\"+ end=+"+
syn region      regoRawString         start=+`+ end=+`+

hi def link     regoString            String
hi def link     regoRawString         String

" Comments; their contents
syn keyword     regoTodo              contained TODO FIXME XXX BUG
syn cluster     regoCommentGroup      contains=regoTodo
syn region      regoComment           start="#" end="$" contains=@regoCommentGroup,@Spell

hi def link     regoComment           Comment
hi def link     regoTodo              Todo

let b:current_syntax = 'rego'
