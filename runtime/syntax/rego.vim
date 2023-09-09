" Vim syntax file
" Language: rego policy language
" Maintainer: Matt Dunford (zenmatic@gmail.com)
" URL:        https://github.com/zenmatic/vim-syntax-rego
" Last Change: 2022 Dec 4

" https://www.openpolicyagent.org/docs/latest/policy-language/

" quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

syn case match

syn keyword regoDirective package import allow deny
syn keyword regoKeywords as default else every false if import package not null true with some in print

syn keyword regoFuncAggregates count sum product max min sort all any
syn match regoFuncArrays "\<array\.\(concat\|slice\|reverse\)\>"
syn keyword regoFuncSets intersection union

syn keyword regoFuncStrings concat /\<contains\>/ endswith format_int indexof indexof_n lower replace split sprintf startswith substring trim trim_left trim_prefix trim_right trim_suffix trim_space upper
syn match regoFuncStrings2 "\<strings\.\(replace_n\|reverse\|any_prefix_match\|any_suffix_match\)\>"
syn match regoFuncStrings3 "\<contains\>"

syn keyword regoFuncRegex re_match
syn match regoFuncRegex2 "\<regex\.\(is_valid\|split\|globs_match\|template_match\|find_n\|find_all_string_submatch_n\|replace\)\>"

syn match regoFuncUuid "\<uuid.rfc4122\>"
syn match regoFuncBits "\<bits\.\(or\|and\|negate\|xor\|lsh\|rsh\)\>"
syn match regoFuncObject "\<object\.\(get\|remove\|subset\|union\|union_n\|filter\)\>"
syn match regoFuncGlob "\<glob\.\(match\|quote_meta\)\>"
syn match regoFuncUnits "\<units\.parse\(_bytes\)\=\>"
syn keyword regoFuncTypes is_number is_string is_boolean is_array is_set is_object is_null type_name
syn match regoFuncEncoding1 "\<base64\.\(encode\|decode\|is_valid\)\>"
syn match regoFuncEncoding2 "\<base64url\.\(encode\(_no_pad\)\=\|decode\)\>"
syn match regoFuncEncoding3 "\<urlquery\.\(encode\|decode\|\(en\|de\)code_object\)\>"
syn match regoFuncEncoding4 "\<\(json\|yaml\)\.\(is_valid\|marshal\|unmarshal\)\>"
syn match regoFuncEncoding5 "\<json\.\(filter\|patch\|remove\)\>"
syn match regoFuncTokenSigning "\<io\.jwt\.\(encode_sign_raw\|encode_sign\)\>"
syn match regoFuncTokenVerification1 "\<io\.jwt\.\(decode\|decode_verify\)\>"
syn match regoFuncTokenVerification2 "\<io\.jwt\.verify_\(rs\|ps\|es\|hs\)\(256\|384\|512\)\>"
syn match regoFuncTime "\<time\.\(now_ns\|parse_ns\|parse_rfc3339_ns\|parse_duration_ns\|date\|clock\|weekday\|diff\|add_date\)\>"
syn match regoFuncCryptography "\<crypto\.x509\.\(parse_certificates\|parse_certificate_request\|parse_and_verify_certificates\|parse_rsa_private_key\)\>"
syn match regoFuncCryptography "\<crypto\.\(md5\|sha1\|sha256\)"
syn match regoFuncCryptography "\<crypto\.hmac\.\(md5\|sha1\|sha256\|sha512\)"
syn keyword regoFuncGraphs walk
syn match regoFuncGraphs2 "\<graph\.reachable\(_paths\)\=\>"
syn match regoFuncGraphQl "\<graphql\.\(\(schema_\)\=is_valid\|parse\(_\(and_verify\|query\|schema\)\)\=\)\>"
syn match regoFuncHttp "\<http\.send\>"
syn match regoFuncNet "\<net\.\(cidr_merge\|cidr_contains\|cidr_contains_matches\|cidr_intersects\|cidr_expand\|lookup_ip_addr\|cidr_is_valid\)\>"
syn match regoFuncRego "\<rego\.\(parse_module\|metadata\.\(rule\|chain\)\)\>"
syn match regoFuncOpa "\<opa\.runtime\>"
syn keyword regoFuncDebugging trace
syn match regoFuncRand "\<rand\.intn\>"

syn match   regoFuncNumbers "\<numbers\.\(range\|intn\)\>"
syn keyword regoFuncNumbers round ceil floor abs

syn match regoFuncSemver "\<semver\.\(is_valid\|compare\)\>"
syn keyword regoFuncConversions to_number
syn match regoFuncHex "\<hex\.\(encode\|decode\)\>"

hi def link regoFuncUuid Statement
hi def link regoFuncBits Statement
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
hi def link regoFuncEncoding4 Statement
hi def link regoFuncEncoding5 Statement
hi def link regoFuncTokenSigning Statement
hi def link regoFuncTokenVerification1 Statement
hi def link regoFuncTokenVerification2 Statement
hi def link regoFuncTime Statement
hi def link regoFuncCryptography Statement
hi def link regoFuncGraphs Statement
hi def link regoFuncGraphQl Statement
hi def link regoFuncGraphs2 Statement
hi def link regoFuncHttp Statement
hi def link regoFuncNet Statement
hi def link regoFuncRego Statement
hi def link regoFuncOpa Statement
hi def link regoFuncDebugging Statement
hi def link regoFuncObject Statement
hi def link regoFuncNumbers Statement
hi def link regoFuncSemver Statement
hi def link regoFuncConversions Statement
hi def link regoFuncHex Statement
hi def link regoFuncRand Statement

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
