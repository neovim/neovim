" Vim syntax file
" Language:             RFC 2614 - An API for Service Location configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword slpconfTodo         contained TODO FIXME XXX NOTE

syn region  slpconfComment      display oneline start='^[#;]' end='$'
                                \ contains=slpconfTodo,@Spell

syn match   slpconfBegin        display '^'
                                \ nextgroup=slpconfTag,
                                \ slpconfComment skipwhite

syn keyword slpconfTag          contained net
                                \ nextgroup=slpconfNetTagDot

syn match   slpconfNetTagDot    contained display '.'
                                \ nextgroup=slpconfNetTag

syn keyword slpconfNetTag       contained slp
                                \ nextgroup=slpconfNetSlpTagdot

syn match   slpconfNetSlpTagDot contained display '.'
                                \ nextgroup=slpconfNetSlpTag

syn keyword slpconfNetSlpTag    contained isDA traceDATraffic traceMsg
                                \ traceDrop traceReg isBroadcastOnly
                                \ passiveDADetection securityEnabled
                                \ nextgroup=slpconfBooleanEq,slpconfBooleanHome
                                \ skipwhite

syn match   slpconfBooleanHome  contained display
                                \ '\.\d\{1,3}\%(\.\d\{1,3}\)\{3}'
                                \ nextgroup=slpconfBooleanEq skipwhite

syn match   slpconfBooleanEq    contained display '='
                                \ nextgroup=slpconfBoolean skipwhite

syn keyword slpconfBoolean      contained true false TRUE FALSE

syn keyword slpconfNetSlpTag    contained DAHeartBeat multicastTTL
                                \ DAActiveDiscoveryInterval
                                \ multicastMaximumWait multicastTimeouts
                                \ randomWaitBound MTU maxResults
                                \ nextgroup=slpconfIntegerEq,slpconfIntegerHome
                                \ skipwhite

syn match   slpconfIntegerHome  contained display
                                \ '\.\d\{1,3}\%(\.\d\{1,3}\)\{3}'
                                \ nextgroup=slpconfIntegerEq skipwhite

syn match   slpconfIntegerEq    contained display '='
                                \ nextgroup=slpconfInteger skipwhite

syn match   slpconfInteger      contained display '\<\d\+\>'

syn keyword slpconfNetSlpTag    contained DAAttributes SAAttributes
                                \ nextgroup=slpconfAttrEq,slpconfAttrHome
                                \ skipwhite

syn match   slpconfAttrHome     contained display
                                \ '\.\d\{1,3}\%(\.\d\{1,3}\)\{3}'
                                \ nextgroup=slpconfAttrEq skipwhite

syn match   slpconfAttrEq       contained display '='
                                \ nextgroup=slpconfAttrBegin skipwhite

syn match   slpconfAttrBegin    contained display '('
                                \ nextgroup=slpconfAttrTag skipwhite

syn match   slpconfAttrTag      contained display
                                \ '[^* \t_(),\\!<=>~[:cntrl:]]\+'
                                \ nextgroup=slpconfAttrTagEq skipwhite

syn match   slpconfAttrTagEq    contained display '='
                                \ nextgroup=@slpconfAttrValue skipwhite

syn cluster slpconfAttrValueCon contains=slpconfAttrValueSep,slpconfAttrEnd

syn cluster slpconfAttrValue    contains=slpconfAttrIValue,slpconfAttrSValue,
                                \ slpconfAttrBValue,slpconfAttrSSValue

syn match   slpconfAttrSValue   contained display '[^ (),\\!<=>~[:cntrl:]]\+'
                                \ nextgroup=@slpconfAttrValueCon skipwhite

syn match   slpconfAttrSSValue  contained display '\\FF\%(\\\x\x\)\+'
                                \ nextgroup=@slpconfAttrValueCon skipwhite

syn match   slpconfAttrIValue   contained display '[-]\=\d\+\>'
                                \ nextgroup=@slpconfAttrValueCon skipwhite

syn keyword slpconfAttrBValue   contained true false
                                \ nextgroup=@slpconfAttrValueCon skipwhite

syn match   slpconfAttrValueSep contained display ','
                                \ nextgroup=@slpconfAttrValue skipwhite

syn match   slpconfAttrEnd      contained display ')'
                                \ nextgroup=slpconfAttrSep skipwhite

syn match   slpconfAttrSep      contained display ','
                                \ nextgroup=slpconfAttrBegin skipwhite

syn keyword slpconfNetSlpTag    contained useScopes typeHint
                                \ nextgroup=slpconfStringsEq,slpconfStringsHome
                                \ skipwhite

syn match   slpconfStringsHome  contained display
                                \ '\.\d\{1,3}\%(\.\d\{1,3}\)\{3}'
                                \ nextgroup=slpconfStringsEq skipwhite

syn match   slpconfStringsEq    contained display '='
                                \ nextgroup=slpconfStrings skipwhite

syn match   slpconfStrings      contained display
                                \ '\%([[:digit:][:alpha:]]\|[!-+./:-@[-`{-~-]\|\\\x\x\)\+'
                                \ nextgroup=slpconfStringsSep skipwhite

syn match   slpconfStringsSep   contained display ','
                                \ nextgroup=slpconfStrings skipwhite

syn keyword slpconfNetSlpTag    contained DAAddresses
                                \ nextgroup=slpconfAddressesEq,slpconfAddrsHome
                                \ skipwhite

syn match   slpconfAddrsHome    contained display
                                \ '\.\d\{1,3}\%(\.\d\{1,3}\)\{3}'
                                \ nextgroup=slpconfAddressesEq skipwhite

syn match   slpconfAddressesEq  contained display '='
                                \ nextgroup=@slpconfAddresses skipwhite

syn cluster slpconfAddresses    contains=slpconfFQDNs,slpconfHostnumbers

syn match   slpconfFQDNs        contained display
                                \ '\a[[:alnum:]-]*[[:alnum:]]\|\a'
                                \ nextgroup=slpconfAddressesSep skipwhite

syn match   slpconfHostnumbers  contained display
                                \ '\d\{1,3}\%(\.\d\{1,3}\)\{3}'
                                \ nextgroup=slpconfAddressesSep skipwhite

syn match   slpconfAddressesSep contained display ','
                                \ nextgroup=@slpconfAddresses skipwhite

syn keyword slpconfNetSlpTag    contained serializedRegURL
                                \ nextgroup=slpconfStringEq,slpconfStringHome
                                \ skipwhite

syn match   slpconfStringHome   contained display
                                \ '\.\d\{1,3}\%(\.\d\{1,3}\)\{3}'
                                \ nextgroup=slpconfStringEq skipwhite

syn match   slpconfStringEq     contained display '='
                                \ nextgroup=slpconfString skipwhite

syn match   slpconfString       contained display
                                \ '\%([!-+./:-@[-`{-~-]\|\\\x\x\)\+\|[[:digit:][:alpha:]]'

syn keyword slpconfNetSlpTag    contained multicastTimeouts DADiscoveryTimeouts
                                \ datagramTimeouts
                                \ nextgroup=slpconfIntegersEq,
                                \ slpconfIntegersHome skipwhite

syn match   slpconfIntegersHome contained display
                                \ '\.\d\{1,3}\%(\.\d\{1,3}\)\{3}'
                                \ nextgroup=slpconfIntegersEq skipwhite

syn match   slpconfIntegersEq   contained display '='
                                \ nextgroup=slpconfIntegers skipwhite

syn match   slpconfIntegers     contained display '\<\d\+\>'
                                \ nextgroup=slpconfIntegersSep skipwhite

syn match   slpconfIntegersSep  contained display ','
                                \ nextgroup=slpconfIntegers skipwhite

syn keyword slpconfNetSlpTag    contained interfaces
                                \ nextgroup=slpconfHostnumsEq,
                                \ slpconfHostnumsHome skipwhite

syn match   slpconfHostnumsHome contained display
                                \ '\.\d\{1,3}\%(\.\d\{1,3}\)\{3}'
                                \ nextgroup=slpconfHostnumsEq skipwhite

syn match   slpconfHostnumsEq   contained display '='
                                \ nextgroup=slpconfOHostnumbers skipwhite

syn match   slpconfOHostnumbers contained display
                                \ '\d\{1,3}\%(\.\d\{1,3}\)\{3}'
                                \ nextgroup=slpconfHostnumsSep skipwhite

syn match   slpconfHostnumsSep  contained display ','
                                \ nextgroup=slpconfOHostnumbers skipwhite

syn keyword slpconfNetSlpTag    contained locale
                                \ nextgroup=slpconfLocaleEq,slpconfLocaleHome
                                \ skipwhite

syn match   slpconfLocaleHome   contained display
                                \ '\.\d\{1,3}\%(\.\d\{1,3}\)\{3}'
                                \ nextgroup=slpconfLocaleEq skipwhite

syn match   slpconfLocaleEq     contained display '='
                                \ nextgroup=slpconfLocale skipwhite

syn match   slpconfLocale       contained display '\a\{1,8}\%(-\a\{1,8}\)\='

hi def link slpconfTodo         Todo
hi def link slpconfComment      Comment
hi def link slpconfTag          Identifier
hi def link slpconfDelimiter    Delimiter
hi def link slpconfNetTagDot    slpconfDelimiter
hi def link slpconfNetTag       slpconfTag
hi def link slpconfNetSlpTagDot slpconfNetTagDot
hi def link slpconfNetSlpTag    slpconfTag
hi def link slpconfHome         Special
hi def link slpconfBooleanHome  slpconfHome
hi def link slpconfEq           Operator
hi def link slpconfBooleanEq    slpconfEq
hi def link slpconfBoolean      Boolean
hi def link slpconfIntegerHome  slpconfHome
hi def link slpconfIntegerEq    slpconfEq
hi def link slpconfInteger      Number
hi def link slpconfAttrHome     slpconfHome
hi def link slpconfAttrEq       slpconfEq
hi def link slpconfAttrBegin    slpconfDelimiter
hi def link slpconfAttrTag      slpconfTag
hi def link slpconfAttrTagEq    slpconfEq
hi def link slpconfAttrIValue   slpconfInteger
hi def link slpconfAttrSValue   slpconfString
hi def link slpconfAttrBValue   slpconfBoolean
hi def link slpconfAttrSSValue  slpconfString
hi def link slpconfSeparator    slpconfDelimiter
hi def link slpconfAttrValueSep slpconfSeparator
hi def link slpconfAttrEnd      slpconfAttrBegin
hi def link slpconfAttrSep      slpconfSeparator
hi def link slpconfStringsHome  slpconfHome
hi def link slpconfStringsEq    slpconfEq
hi def link slpconfStrings      slpconfString
hi def link slpconfStringsSep   slpconfSeparator
hi def link slpconfAddrsHome    slpconfHome
hi def link slpconfAddressesEq  slpconfEq
hi def link slpconfFQDNs        String
hi def link slpconfHostnumbers  Number
hi def link slpconfAddressesSep slpconfSeparator
hi def link slpconfStringHome   slpconfHome
hi def link slpconfStringEq     slpconfEq
hi def link slpconfString       String
hi def link slpconfIntegersHome slpconfHome
hi def link slpconfIntegersEq   slpconfEq
hi def link slpconfIntegers     slpconfInteger
hi def link slpconfIntegersSep  slpconfSeparator
hi def link slpconfHostnumsHome slpconfHome
hi def link slpconfHostnumsEq   slpconfEq
hi def link slpconfOHostnumbers slpconfHostnumbers
hi def link slpconfHostnumsSep  slpconfSeparator
hi def link slpconfLocaleHome   slpconfHome
hi def link slpconfLocaleEq     slpconfEq
hi def link slpconfLocale       slpconfString

let b:current_syntax = "slpconf"

let &cpo = s:cpo_save
unlet s:cpo_save
