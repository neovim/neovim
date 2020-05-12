" Vim syntax file
" Language: hog (Snort.conf + .rules)
" Maintainer: Victor Roemer, <vroemer@badsec.org>.
" Last Change: 2015 Oct 24  -> Rename syntax items from Snort -> Hog
"              2012 Oct 24  -> Originalish release

" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

setlocal iskeyword-=:
setlocal iskeyword+=-
syn case ignore

" Hog ruletype crap
syn keyword     HogRuleType       ruletype nextgroup=HogRuleTypeName skipwhite
syn match       HogRuleTypeName   "[[:alnum:]_]\+" contained nextgroup=HogRuleTypeBody skipwhite
syn region      HogRuleTypeBody   start="{" end="}" contained contains=HogRuleTypeType,HogOutput fold
syn keyword     HogRuleTypeType   type contained

" Hog Configurables
syn keyword     HogPreproc    preprocessor nextgroup=HogConfigName skipwhite
syn keyword     HogConfig     config nextgroup=HogConfigName skipwhite
syn keyword     HogOutput     output nextgroup=HogConfigName skipwhite
syn match       HogConfigName "[[:alnum:]_-]\+" contained nextgroup=HogConfigOpts skipwhite
syn region      HogConfigOpts start=":" skip="\\.\{-}$\|^\s*#.\{-}$\|^\s*$" end="$" fold keepend contained contains=HogSpecial,HogNumber,HogIPAddr,HogVar,HogComment

" Event filter's and threshold's
syn region      HogEvFilter         start="event_filter\|threshold" skip="\\.\{-}$\|^\s*#.\{-}$\|^\s*$" end="$" fold transparent keepend contains=HogEvFilterKeyword,HogEvFilterOptions,HogComment
syn keyword     HogEvFilterKeyword  skipwhite event_filter threshold
syn keyword     HogEvFilterOptions  skipwhite type nextgroup=HogEvFilterTypes
syn keyword     HogEvFilterTypes    skipwhite limit threshold both contained
syn keyword     HogEvFilterOptions  skipwhite track nextgroup=HogEvFilterTrack
syn keyword     HogEvFilterTrack    skipwhite by_src by_dst contained
syn keyword     HogEvFilterOptions  skipwhite gen_id sig_id count seconds nextgroup=HogNumber

" Suppressions
syn region      HogEvFilter         start="suppress" skip="\\.\{-}$\|^\s*#.\{-}$\|^\s*$" end="$" fold transparent keepend contains=HogSuppressKeyword,HogComment
syn keyword     HogSuppressKeyword  skipwhite suppress
syn keyword     HogSuppressOptions  skipwhite gen_id sig_id nextgroup=HogNumber
syn keyword     HogSuppressOptions  skipwhite track nextgroup=HogEvFilterTrack
syn keyword     HogSuppressOptions  skipwhite ip nextgroup=HogIPAddr

" Attribute table
syn keyword     HogAttribute        attribute_table nextgroup=HogAttributeFile
syn match       HogAttributeFile    contained ".*$" contains=HogVar,HogAttributeType,HogComment
syn keyword     HogAttributeType    filename

" Hog includes
syn keyword     HogInclude    include nextgroup=HogIncludeFile skipwhite
syn match       HogIncludeFile ".*$" contained contains=HogVar,HogComment

" Hog dynamic libraries
syn keyword     HogDylib      dynamicpreprocessor dynamicengine dynamicdetection nextgroup=HogDylibFile skipwhite
syn match       HogDylibFile  "\s.*$" contained contains=HogVar,HogDylibType,HogComment
syn keyword     HogDylibType  directory file contained

" Variable dereferenced with '$'
syn match       HogVar        "\$[[:alnum:]_]\+"

", Variables declared with 'var'
syn keyword     HogVarType    var nextgroup=HogVarSet skipwhite
syn match       HogVarSet     "[[:alnum:]_]\+" display contained nextgroup=HogVarValue skipwhite
syn match       HogVarValue   ".*$" contained contains=HogString,HogNumber,HogVar,HogComment

" Variables declared with 'ipvar'
syn keyword     HogIPVarType  ipvar nextgroup=HogIPVarSet skipwhite
syn match       HogIPVarSet   "[[:alnum:]_]\+" display contained nextgroup=HogIPVarList,HogSpecial skipwhite
syn region      HogIPVarList  start="\[" end="]" contains=HogIPVarList,HogIPAddr,HogVar,HogOpNot

" Variables declared with 'portvar'
syn keyword     HogPortVarType portvar nextgroup=HogPortVarSet skipwhite
syn match       HogPortVarSet "[[:alnum:]_]\+" display contained nextgroup=HogPortVarList,HogPort,HogOpRange,HogOpNot,HogSpecial skipwhite
syn region      HogPortVarList start="\[" end="]" contains=HogPortVarList,HogVar,HogOpNot,HogPort,HogOpRange,HogOpNot
syn match       HogPort       "\<\%(\d\+\|any\)\>" display contains=HogOpRange nextgroup=HogOpRange

" Generic stuff
syn match       HogIPAddr     contained "\<\%(\d\{1,3}\(\.\d\{1,3}\)\{3}\|any\)\>" nextgroup=HogIPCidr
syn match       HogIPAddr     contained "\<\d\{1,3}\(\.\d\{1,3}\)\{3}\>" nextgroup=HogIPCidr
syn match       HogIPCidr     contained "\/\([0-2][0-9]\=\|3[0-2]\=\)"
syn region      HogHexEsc     contained start='|' end='|' oneline
syn region      HogString     contained start='"' end='"' extend oneline contains=HogHexEsc
syn match       HogNumber     contained display "\<\d\+\>"
syn match       HogNumber     contained display "\<\d\+\>"
syn match       HogNumber     contained display "0x\x\+\>"
syn keyword     HogSpecial    contained true false yes no default all any
syn keyword     HogSpecialAny contained any
syn match       HogOpNot      "!" contained
syn match       HogOpRange    ":" contained

" Rules
syn keyword     HogRuleAction     activate alert drop block dynamic log pass reject sdrop sblock skipwhite nextgroup=HogRuleProto,HogRuleBlock
syn keyword     HogRuleProto      ip tcp udp icmp skipwhite contained nextgroup=HogRuleSrcIP
syn match       HogRuleSrcIP      "\S\+" transparent skipwhite contained contains=HogIPVarList,HogIPAddr,HogVar,HogOpNot nextgroup=HogRuleSrcPort
syn match       HogRuleSrcPort    "\S\+" transparent skipwhite contained contains=HogPortVarList,HogVar,HogPort,HogOpRange,HogOpNot nextgroup=HogRuleDir
syn match       HogRuleDir        "->\|<>" skipwhite contained nextgroup=HogRuleDstIP
syn match       HogRuleDstIP      "\S\+" transparent skipwhite contained contains=HogIPVarList,HogIPAddr,HogVar,HogOpNot nextgroup=HogRuleDstPort
syn match       HogRuleDstPort    "\S\+" transparent skipwhite contained contains=HogPortVarList,HogVar,HogPort,HogOpRange,HogOpNot nextgroup=HogRuleBlock
syn region      HogRuleBlock      start="(" end=")" transparent skipwhite contained contains=HogRuleOption,HogComment fold
",HogString,HogComment,HogVar,HogOptNot
"syn region      HogRuleOption     start="\<gid\|sid\|rev\|depth\|offset\|distance\|within\>" end="\ze;" skipwhite contained contains=HogNumber
syn keyword     HogRuleOption   skipwhite contained nextgroup=HogRuleSROP msg gid sid rev classtype priority metadata content nocase rawbytes
syn keyword     HogRuleOption   skipwhite contained nextgroup=HogRuleSROP depth offset distance within http_client_body http_cookie http_raw_cookie http_header
syn keyword     HogRuleOption   skipwhite contained nextgroup=HogRuleSROP http_raw_header http_method http_uri http_raw_uri http_stat_code http_stat_msg
syn keyword     HogRuleOption   skipwhite contained nextgroup=HogRuleSROP fast_pattern uricontent urilen isdataat pcre pkt_data file_data base64_decode base64_data
syn keyword     HogRuleOption   skipwhite contained nextgroup=HogRuleSROP byte_test byte_jump byte_extract ftpbounce asn1 cvs dce_iface dce_opnum dce_stub_data
syn keyword     HogRuleOption   skipwhite contained nextgroup=HogRuleSROP sip_method sip_stat_code sip_header sip_body gtp_type gtp_info gtp_version ssl_version
syn keyword     HogRuleOption   skipwhite contained nextgroup=HogRuleSROP ssl_state fragoffset ttl tos id ipopts fragbits dsize flags flow flowbits seq ack window
syn keyword     HogRuleOption   skipwhite contained nextgroup=HogRuleSROP itype icode icmp_id icmp_seq rpc ip_proto sameip stream_reassemble stream_size
syn keyword     HogRuleOption   skipwhite contained nextgroup=HogRuleSROP logto session resp react tag activates activated_by count replace detection_filter
syn keyword     HogRuleOption   skipwhite contained nextgroup=HogRuleSROP threshold reference sd_pattern file_type file_group

syn region      HogRuleSROP     start=':' end=";" transparent keepend contained contains=HogRuleChars,HogString,HogNumber
syn match       HogRuleChars    "\%(\k\|\.\|?\|=\|/\|%\|&\)\+" contained
syn match       HogURLChars     "\%(\.\|?\|=\)\+" contained

" Hog File Type Rules
syn match       HogFileType   /^\s*file.*$/ transparent contains=HogFileTypeOpt,HogFileFROP
syn keyword     HogFileTypeOpt  skipwhite contained nextgroup=HogRuleFROP file type ver category id rev content offset msg group 
syn region      HogFileFROP  start=':' end=";" transparent keepend contained contains=NotASemicoln
syn match       NotASemiColn   ".*$" contained


" Comments
syn keyword HogTodo   XXX TODO NOTE contained
syn match   HogTodo   "Step\s\+#\=\d\+" contained
syn region HogComment start="#" end="$" contains=HogTodo,@Spell

syn case match

if !exists("hog_minlines")
    let hog_minlines = 100
endif
exec "syn sync minlines=" . hog_minlines

hi link HogRuleType           Statement
hi link HogRuleTypeName       Type
hi link HogRuleTypeType       Keyword

hi link HogPreproc            Statement
hi link HogConfig             Statement
hi link HogOutput             Statement
hi link HogConfigName         Type

"hi link HogEvFilter
hi link HogEvFilterKeyword    Statement
hi link HogSuppressKeyword    Statement
hi link HogEvFilterTypes      Constant
hi link HogEvFilterTrack      Constant

hi link HogAttribute          Statement
hi link HogAttributeFile      String
hi link HogAttributeType      Statement

hi link HogInclude            Statement
hi link HogIncludeFile        String

hi link HogDylib              Statement
hi link HogDylibType          Statement
hi link HogDylibFile          String

" Variables
" var
hi link HogVar                Identifier
hi link HogVarType            Keyword
hi link HogVarSet             Identifier
hi link HogVarValue           String
" ipvar
hi link HogIPVarType          Keyword
hi link HogIPVarSet           Identifier
" portvar
hi link HogPortVarType         Keyword
hi link HogPortVarSet          Identifier
hi link HogPort                Constant

hi link HogTodo               Todo
hi link HogComment            Comment
hi link HogString             String
hi link HogHexEsc             PreProc
hi link HogNumber             Number
hi link HogSpecial            Constant
hi link HogSpecialAny         Constant
hi link HogIPAddr             Constant
hi link HogIPCidr             Constant
hi link HogOpNot              Operator
hi link HogOpRange            Operator

hi link HogRuleAction         Statement
hi link HogRuleProto          Identifier
hi link HogRuleDir            Operator
hi link HogRuleOption         Keyword
hi link HogRuleChars           String 

hi link HogFileType    HogRuleAction
hi link HogFileTypeOpt HogRuleOption
hi link NotASemiColn     HogRuleChars

let b:current_syntax = "hog"
