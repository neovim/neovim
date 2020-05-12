" Vim syntax file
" Language:             RFC 2614 - An API for Service Location registration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword slpregTodo          contained TODO FIXME XXX NOTE

syn region  slpregComment       display oneline start='^[#;]' end='$'
                                \ contains=slpregTodo,@Spell

syn match   slpregBegin         display '^'
                                \ nextgroup=slpregServiceURL,
                                \ slpregComment

syn match   slpregServiceURL    contained display 'service:'
                                \ nextgroup=slpregServiceType

syn match   slpregServiceType   contained display '\a[[:alpha:][:digit:]+-]*\%(\.\a[[:alpha:][:digit:]+-]*\)\=\%(:\a[[:alpha:][:digit:]+-]*\)\='
                                \ nextgroup=slpregServiceSAPCol

syn match   slpregServiceSAPCol contained display ':'
                                \ nextgroup=slpregSAP

syn match   slpregSAP           contained '[^,]\+'
                                \ nextgroup=slpregLangSep
"syn match   slpregSAP           contained display '\%(//\%(\%([[:alpha:][:digit:]$-_.~!*\'(),+;&=]*@\)\=\%([[:alnum:]][[:alnum:]-]*[[:alnum:]]\|[[:alnum:]]\.\)*\%(\a[[:alnum:]-]*[[:alnum:]]\|\a\)\%(:\d\+\)\=\)\=\|/at/\%([[:alpha:][:digit:]$-_.~]\|\\\x\x\)\{1,31}:\%([[:alpha:][:digit:]$-_.~]\|\\\x\x\)\{1,31}\%([[:alpha:][:digit:]$-_.~]\|\\\x\x\)\{1,31}\|/ipx/\x\{8}:\x\{12}:\x\{4}\)\%(/\%([[:alpha:][:digit:]$-_.~!*\'()+;?:@&=+]\|\\\x\x\)*\)*\%(;[^()\\!<=>~[:cntrl:]* \t_]\+\%(=[^()\\!<=>~[:cntrl:] ]\+\)\=\)*'

syn match   slpregLangSep       contained display ','
                                \ nextgroup=slpregLang

syn match   slpregLang          contained display '\a\{1,8}\%(-\a\{1,8\}\)\='
                                \ nextgroup=slpregLTimeSep

syn match   slpregLTimeSep      contained display ','
                                \ nextgroup=slpregLTime

syn match   slpregLTime         contained display '\d\{1,5}'
                                \ nextgroup=slpregType,slpregUNewline

syn match   slpregType          contained display '\a[[:alpha:][:digit:]+-]*'
                                \ nextgroup=slpregUNewLine

syn match   slpregUNewLine      contained '\s*\n'
                                \ nextgroup=slpregScopes,slpregAttrList skipnl

syn keyword slpregScopes        contained scopes
                                \ nextgroup=slpregScopesEq

syn match   slpregScopesEq      contained '=' nextgroup=slpregScopeName

syn match   slpregScopeName     contained '[^(),\\!<=>[:cntrl:];*+ ]\+'
                                \ nextgroup=slpregScopeNameSep,
                                \ slpregScopeNewline

syn match   slpregScopeNameSep  contained ','
                                \ nextgroup=slpregScopeName

syn match   slpregScopeNewline  contained '\s*\n'
                                \ nextgroup=slpregAttribute skipnl

syn match   slpregAttribute     contained '[^(),\\!<=>[:cntrl:]* \t_]\+'
                                \ nextgroup=slpregAttributeEq,
                                \ slpregScopeNewline

syn match   slpregAttributeEq   contained '='
                                \ nextgroup=@slpregAttrValue

syn cluster slpregAttrValueCon  contains=slpregAttribute,slpregAttrValueSep

syn cluster slpregAttrValue     contains=slpregAttrIValue,slpregAttrSValue,
                                \ slpregAttrBValue,slpregAttrSSValue

syn match   slpregAttrSValue    contained display '[^(),\\!<=>~[:cntrl:]]\+'
                                \ nextgroup=@slpregAttrValueCon skipwhite skipnl

syn match   slpregAttrSSValue   contained display '\\FF\%(\\\x\x\)\+'
                                \ nextgroup=@slpregAttrValueCon skipwhite skipnl

syn match   slpregAttrIValue    contained display '[-]\=\d\+\>'
                                \ nextgroup=@slpregAttrValueCon skipwhite skipnl

syn keyword slpregAttrBValue    contained true false
                                \ nextgroup=@slpregAttrValueCon skipwhite skipnl

syn match   slpregAttrValueSep  contained display ','
                                \ nextgroup=@slpregAttrValue skipwhite skipnl

hi def link slpregTodo          Todo
hi def link slpregComment       Comment
hi def link slpregServiceURL    Type
hi def link slpregServiceType   slpregServiceURL
hi def link slpregServiceSAPCol slpregServiceURL
hi def link slpregSAP           slpregServiceURL
hi def link slpregDelimiter     Delimiter
hi def link slpregLangSep       slpregDelimiter
hi def link slpregLang          String
hi def link slpregLTimeSep      slpregDelimiter
hi def link slpregLTime         Number
hi def link slpregType          Type
hi def link slpregScopes        Identifier
hi def link slpregScopesEq      Operator
hi def link slpregScopeName     String
hi def link slpregScopeNameSep  slpregDelimiter
hi def link slpregAttribute     Identifier
hi def link slpregAttributeEq   Operator
hi def link slpregAttrSValue    String
hi def link slpregAttrSSValue   slpregAttrSValue
hi def link slpregAttrIValue    Number
hi def link slpregAttrBValue    Boolean
hi def link slpregAttrValueSep  slpregDelimiter

let b:current_syntax = "slpreg"

let &cpo = s:cpo_save
unlet s:cpo_save
