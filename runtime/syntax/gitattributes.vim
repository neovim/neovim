" Vim syntax file
" Language:	git attributes
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Filenames:	.gitattributes, *.git/info/attributes
" Last Change:	2022 Sep 09

if exists('b:current_syntax')
    finish
endif

let s:cpo_save = &cpoptions
set cpoptions&vim

" Comment
syn keyword gitattributesTodo contained TODO FIXME XXX
syn match gitattributesComment /^\s*#.*/ contains=gitattributesTodo

" Pattern
syn match gitattributesPattern /^\s*#\@!\(".\+"\|\S\+\)/ skipwhite
            \ nextgroup=gitattributesAttrPrefixed,gitattributesAttrAssigned skipwhite
            \ contains=gitattributesGlob,gitattributesRange,gitattributesSeparator
syn match gitattributesGlob /\\\@1<![?*]/ contained
syn match gitattributesRange /\\\@1<!\[.\{-}\]/ contained
syn match gitattributesSeparator '/' contained

" Attribute
syn match gitattributesAttrPrefixed /[!-]\?[A-Za-z0-9_.][-A-Za-z0-9_.]*/
            \ transparent contained skipwhite
            \ nextgroup=gitattributesAttrPrefixed,gitattributesAttrAssigned
            \ contains=gitattributesPrefix,gitattributesName
syn match gitattributesAttrAssigned /[A-Za-z0-9_.][-A-Za-z0-9_.]*=\S\+/
            \ transparent contained skipwhite
            \ nextgroup=gitattributesAttrPrefixed,gitattributesAttrAssigned
            \ contains=gitattributesName,gitattributesAssign,gitattributesBoolean,gitattributesString
syn match gitattributesName /[A-Za-z0-9_.][-A-Za-z0-9_.]*/
            \ contained nextgroup=gitattributesAssign
syn match gitattributesPrefix /[!-]/ contained
            \ nextgroup=gitAttributesName
syn match gitattributesAssign '=' contained
            \ nextgroup=gitattributesBoolean,gitattributesString
syn match gitattributesString /=\@1<=\S\+/ contained
syn keyword gitattributesBoolean true false contained

" Macro
syn match gitattributesMacro /^\s*\[attr\]\s*\S\+/
            \ nextgroup=gitattributesAttribute skipwhite

hi def link gitattributesAssign Operator
hi def link gitattributesBoolean Boolean
hi def link gitattributesComment Comment
hi def link gitattributesGlob Special
hi def link gitattributesMacro Define
hi def link gitattributesName Identifier
hi def link gitattributesPrefix SpecialChar
hi def link gitattributesRange Special
hi def link gitattributesSeparator Delimiter
hi def link gitattributesString String
hi def link gitattributesTodo Todo

let b:current_syntax = 'gitattributes'

let &cpoptions = s:cpo_save
unlet s:cpo_save
