" Vim syntax file
" Language:         YAML (YAML Ain't Markup Language) 1.2
" Maintainer:       Nikolai Pavlov <zyx.vim@gmail.com>
" First author:     Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2010-10-08

if exists('b:current_syntax')
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

let s:ns_char = '\%(\%([\n\r\uFEFF \t]\)\@!\p\)'
let s:ns_word_char = '\%(\w\|-\)'
let s:ns_uri_char  = '\%(%\x\x\|'.s:ns_word_char.'\|[#/;?:@&=+$,.!~*''()\[\]]\)'
let s:ns_tag_char  = '\%(%\x\x\|'.s:ns_word_char.'\|[#/;?:@&=+$.~*''()]\)'
let s:c_ns_anchor_char = '\%(\%([\n\r\uFEFF \t,\[\]{}]\)\@!\p\)'
let s:c_indicator      = '[\-?:,\[\]{}#&*!|>''"%@`]'
let s:c_flow_indicator = '[,\[\]{}]'

let s:c_verbatim_tag = '!<'.s:ns_uri_char.'\+>'
let s:c_named_tag_handle     = '!'.s:ns_word_char.'\+!'
let s:c_secondary_tag_handle = '!!'
let s:c_primary_tag_handle   = '!'
let s:c_tag_handle = '\%('.s:c_named_tag_handle.
            \         '\|'.s:c_secondary_tag_handle.
            \         '\|'.s:c_primary_tag_handle.'\)'
let s:c_ns_shorthand_tag = s:c_tag_handle . s:ns_tag_char.'\+'
let s:c_non_specific_tag = '!'
let s:c_ns_tag_property = s:c_verbatim_tag.
            \        '\|'.s:c_ns_shorthand_tag.
            \        '\|'.s:c_non_specific_tag

let s:c_ns_anchor_name = s:c_ns_anchor_char.'\+'
let s:c_ns_anchor_property =  '&'.s:c_ns_anchor_name
let s:c_ns_alias_node      = '\*'.s:c_ns_anchor_name

let s:ns_directive_name = s:ns_char.'\+'

let s:ns_local_tag_prefix  = '!'.s:ns_uri_char.'*'
let s:ns_global_tag_prefix = s:ns_tag_char.s:ns_uri_char.'*'
let s:ns_tag_prefix = s:ns_local_tag_prefix.
            \    '\|'.s:ns_global_tag_prefix

let s:ns_plain_safe_out = s:ns_char
let s:ns_plain_safe_in  = '\%('.s:c_flow_indicator.'\@!'.s:ns_char.'\)'

let s:ns_plain_first_in  = '\%('.s:c_indicator.'\@!'.s:ns_char.'\|[?:\-]\%('.s:ns_plain_safe_in.'\)\@=\)'
let s:ns_plain_first_out = '\%('.s:c_indicator.'\@!'.s:ns_char.'\|[?:\-]\%('.s:ns_plain_safe_out.'\)\@=\)'

let s:ns_plain_char_in  = '\%('.s:ns_char.'#\|:'.s:ns_plain_safe_in.'\|[:#]\@!'.s:ns_plain_safe_in.'\)'
let s:ns_plain_char_out = '\%('.s:ns_char.'#\|:'.s:ns_plain_safe_out.'\|[:#]\@!'.s:ns_plain_safe_out.'\)'

let s:ns_plain_out = s:ns_plain_first_out . s:ns_plain_char_out.'*'
let s:ns_plain_in  = s:ns_plain_first_in  . s:ns_plain_char_in.'*'


syn keyword yamlTodo            contained TODO FIXME XXX NOTE

syn region  yamlComment         display oneline start='\%\(^\|\s\)#' end='$'
            \                   contains=yamlTodo

execute 'syn region yamlDirective oneline start='.string('^\ze%'.s:ns_directive_name.'\s\+').' '.
            \                            'end="$" '.
            \                            'contains=yamlTAGDirective,'.
            \                                     'yamlYAMLDirective,'.
            \                                     'yamlReservedDirective '.
            \                            'keepend'

syn match yamlTAGDirective '%TAG\s\+' contained nextgroup=yamlTagHandle
execute 'syn match yamlTagHandle contained nextgroup=yamlTagPrefix '.string(s:c_tag_handle.'\s\+')
execute 'syn match yamlTagPrefix contained nextgroup=yamlComment ' . string(s:ns_tag_prefix)

syn match yamlYAMLDirective '%YAML\s\+'  contained nextgroup=yamlYAMLVersion
syn match yamlYAMLVersion   '\d\+\.\d\+' contained nextgroup=yamlComment

execute 'syn match yamlReservedDirective contained nextgroup=yamlComment '.
            \string('%\%(\%(TAG\|YAML\)\s\)\@!'.s:ns_directive_name)

syn region yamlFlowString matchgroup=yamlFlowStringDelimiter start='"' skip='\\"' end='"'
            \ contains=yamlEscape
            \ nextgroup=yamlKeyValueDelimiter
syn region yamlFlowString matchgroup=yamlFlowStringDelimiter start="'" skip="''"  end="'"
            \ contains=yamlSingleEscape
            \ nextgroup=yamlKeyValueDelimiter
syn match  yamlEscape contained '\\\%([\\"abefnrtv\^0_ NLP\n]\|x\x\x\|u\x\{4}\|U\x\{8}\)'
syn match  yamlSingleEscape contained "''"

syn match yamlBlockScalarHeader contained '\s\+\zs[|>]\%([+-]\=[1-9]\|[1-9]\=[+-]\)\='

syn cluster yamlFlow contains=yamlFlowString,yamlFlowMapping,yamlFlowCollection
syn cluster yamlFlow      add=yamlFlowMappingKey,yamlFlowMappingMerge
syn cluster yamlFlow      add=yamlConstant,yamlPlainScalar,yamlFloat
syn cluster yamlFlow      add=yamlTimestamp,yamlInteger,yamlMappingKeyStart
syn cluster yamlFlow      add=yamlComment
syn region yamlFlowMapping    matchgroup=yamlFlowIndicator start='{' end='}' contains=@yamlFlow
syn region yamlFlowCollection matchgroup=yamlFlowIndicator start='\[' end='\]' contains=@yamlFlow

execute 'syn match yamlPlainScalar /'.s:ns_plain_out.'/'
execute 'syn match yamlPlainScalar contained /'.s:ns_plain_in.'/'

syn match yamlMappingKeyStart '?\ze\s'
syn match yamlMappingKeyStart '?' contained

execute 'syn match yamlFlowMappingKey /'.s:ns_plain_in.'\ze\s*:/ contained '.
            \'nextgroup=yamlKeyValueDelimiter'
syn match yamlFlowMappingMerge /<<\ze\s*:/ contained nextgroup=yamlKeyValueDelimiter

syn match yamlBlockCollectionItemStart '^\s*\zs-\%(\s\+-\)*\s' nextgroup=yamlBlockMappingKey,yamlBlockMappingMerge
" Use the old regexp engine, the NFA engine doesn't like all the \@ items.
execute 'syn match yamlBlockMappingKey /\%#=1^\s*\zs'.s:ns_plain_out.'\ze\s*:\%(\s\|$\)/ '.
            \'nextgroup=yamlKeyValueDelimiter'
execute 'syn match yamlBlockMappingKey /\%#=1\s*\zs'.s:ns_plain_out.'\ze\s*:\%(\s\|$\)/ contained '.
            \'nextgroup=yamlKeyValueDelimiter'
syn match yamlBlockMappingMerge /^\s*\zs<<\ze:\%(\s\|$\)/ nextgroup=yamlKeyValueDelimiter
syn match yamlBlockMappingMerge /<<\ze\s*:\%(\s\|$\)/ nextgroup=yamlKeyValueDelimiter contained

syn match   yamlKeyValueDelimiter /\s*:/ contained
syn match   yamlKeyValueDelimiter /\s*:/ contained

syn keyword yamlConstant true True TRUE false False FALSE
syn keyword yamlConstant null Null NULL
syn match   yamlConstant '\<\~\>'

syn match   yamlTimestamp /\%([\[\]{}, \t]\@!\p\)\@<!\%(\d\{4}-\d\d\=-\d\d\=\%(\%([Tt]\|\s\+\)\%(\d\d\=\):\%(\d\d\):\%(\d\d\)\%(\.\%(\d*\)\)\=\%(\s*\%(Z\|[+-]\d\d\=\%(:\d\d\)\=\)\)\=\)\=\)\%([\[\]{}, \t]\@!\p\)\@!/

syn match   yamlInteger /\%([\[\]{}, \t]\@!\p\)\@<!\%([+-]\=\%(0\%(b[0-1_]\+\|[0-7_]\+\|x[0-9a-fA-F_]\+\)\=\|\%([1-9][0-9_]*\%(:[0-5]\=\d\)\+\)\)\|[1-9][0-9_]*\)\%([\[\]{}, \t]\@!\p\)\@!/
syn match   yamlFloat   /\%([\[\]{}, \t]\@!\p\)\@<!\%([+-]\=\%(\%(\d[0-9_]*\)\.[0-9_]*\%([eE][+-]\d\+\)\=\|\.[0-9_]\+\%([eE][-+][0-9]\+\)\=\|\d[0-9_]*\%(:[0-5]\=\d\)\+\.[0-9_]*\|\.\%(inf\|Inf\|INF\)\)\|\%(\.\%(nan\|NaN\|NAN\)\)\)\%([\[\]{}, \t]\@!\p\)\@!/

execute 'syn match yamlNodeTag '.string(s:c_ns_tag_property)
execute 'syn match yamlAnchor  '.string(s:c_ns_anchor_property)
execute 'syn match yamlAlias   '.string(s:c_ns_alias_node)

syn match yamlDocumentStart '^---\ze\%(\s\|$\)'
syn match yamlDocumentEnd   '^\.\.\.\ze\%(\s\|$\)'

hi def link yamlTodo                     Todo
hi def link yamlComment                  Comment

hi def link yamlDocumentStart            PreProc
hi def link yamlDocumentEnd              PreProc

hi def link yamlDirectiveName            Keyword

hi def link yamlTAGDirective             yamlDirectiveName
hi def link yamlTagHandle                String
hi def link yamlTagPrefix                String

hi def link yamlYAMLDirective            yamlDirectiveName
hi def link yamlReservedDirective        Error
hi def link yamlYAMLVersion              Number

hi def link yamlString                   String
hi def link yamlFlowString               yamlString
hi def link yamlFlowStringDelimiter      yamlString
hi def link yamlEscape                   SpecialChar
hi def link yamlSingleEscape             SpecialChar

hi def link yamlBlockCollectionItemStart Label
hi def link yamlBlockMappingKey          Identifier
hi def link yamlBlockMappingMerge        Special

hi def link yamlFlowMappingKey           Identifier
hi def link yamlFlowMappingMerge         Special

hi def link yamlMappingKeyStart          Special
hi def link yamlFlowIndicator            Special
hi def link yamlKeyValueDelimiter        Special

hi def link yamlConstant                 Constant

hi def link yamlAnchor                   Type
hi def link yamlAlias                    Type
hi def link yamlNodeTag                  Type

hi def link yamlInteger                  Number
hi def link yamlFloat                    Float
hi def link yamlTimestamp                Number

let b:current_syntax = "yaml"

unlet s:ns_word_char s:ns_uri_char s:c_verbatim_tag s:c_named_tag_handle s:c_secondary_tag_handle s:c_primary_tag_handle s:c_tag_handle s:ns_tag_char s:c_ns_shorthand_tag s:c_non_specific_tag s:c_ns_tag_property s:c_ns_anchor_char s:c_ns_anchor_name s:c_ns_anchor_property s:c_ns_alias_node s:ns_char s:ns_directive_name s:ns_local_tag_prefix s:ns_global_tag_prefix s:ns_tag_prefix s:c_indicator s:ns_plain_safe_out s:c_flow_indicator s:ns_plain_safe_in s:ns_plain_first_in s:ns_plain_first_out s:ns_plain_char_in s:ns_plain_char_out s:ns_plain_out s:ns_plain_in

let &cpo = s:cpo_save
unlet s:cpo_save

