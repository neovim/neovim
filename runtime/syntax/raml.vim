" Vim syntax file
" Language:    RAML (RESTful API Modeling Language)
" Maintainer:  Eric Hopkins <eric.on.tech@gmail.com>
" URL:         https://github.com/in3d/vim-raml
" License:     Same as Vim
" Last Change: 2018-11-03

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword ramlTodo            contained TODO FIXME XXX NOTE

syn region  ramlComment         display oneline start='\%(^\|\s\)#' end='$'
                                \ contains=ramlTodo,@Spell

syn region  ramlVersion         display oneline start='#%RAML' end='$'

syn match   ramlNodeProperty    '!\%(![^\\^%     ]\+\|[^!][^:/   ]*\)'

syn match   ramlAnchor          '&.\+'

syn match   ramlAlias           '\*.\+'

syn match   ramlDelimiter       '[-,:]'
syn match   ramlBlock           '[\[\]{}>|]'
syn match   ramlOperator        '[?+-]'
syn match   ramlKey             '\h\+\(?\)\?\ze\s*:'
syn match   ramlKey             '\w\+\(\s\+\w\+\)*\(?\)\?\ze\s*:'
syn match   routeKey            '\/\w\+\(\s\+\w\+\)*\ze\s*:'
syn match   routeKey            'application\/\w\+\ze\s*:'
syn match   routeParamKey       '\/{\w\+}*\ze\s*:'

syn region  ramlString          matchgroup=ramlStringDelimiter
                                \ start=+\s"+ skip=+\\"+ end=+"+
                                \ contains=ramlEscape
syn region  ramlString          matchgroup=ramlStringDelimiter
                                \ start=+\s'+ skip=+''+ end=+'+
                                \ contains=ramlStringEscape
syn region  ramlParameter       matchgroup=ramlParameterDelimiter
                                \ start=+<<+ skip=+''+ end=+>>+
syn match   ramlEscape          contained display +\\[\\"abefnrtv^0_ NLP]+
syn match   ramlEscape          contained display '\\x\x\{2}'
syn match   ramlEscape          contained display '\\u\x\{4}'
syn match   ramlEscape          contained display '\\U\x\{8}'
syn match   ramlEscape          display '\\\%(\r\n\|[\r\n]\)'
syn match   ramlStringEscape    contained +''+

syn match   ramlNumber          display
                                \ '\<[+-]\=\d\+\%(\.\d\+\%([eE][+-]\=\d\+\)\=\)\='
syn match   ramlNumber          display '0\o\+'
syn match   ramlNumber          display '0x\x\+'
syn match   ramlNumber          display '([+-]\=[iI]nf)'
syn match   ramlNumber          display '(NaN)'

syn match   ramlConstant        '\<[~yn]\>'
syn keyword ramlConstant        true True TRUE false False FALSE
syn keyword ramlConstant        yes Yes on ON no No off OFF
syn keyword ramlConstant        null Null NULL nil Nil NIL

syn keyword httpVerbs           get post put delete head patch options
syn keyword ramlTypes           string number integer date boolean file

syn match   ramlTimestamp       '\d\d\d\d-\%(1[0-2]\|\d\)-\%(3[0-2]\|2\d\|1\d\|\d\)\%( \%([01]\d\|2[0-3]\):[0-5]\d:[0-5]\d.\d\d [+-]\%([01]\d\|2[0-3]\):[0-5]\d\|t\%([01]\d\|2[0-3]\):[0-5]\d:[0-5]\d.\d\d[+-]\%([01]\d\|2[0-3]\):[0-5]\d\|T\%([01]\d\|2[0-3]\):[0-5]\d:[0-5]\d.\dZ\)\='

syn region  ramlDocumentHeader  start='---' end='$' contains=ramlDirective
syn match   ramlDocumentEnd     '\.\.\.'

syn match   ramlDirective       contained '%[^:]\+:.\+'

hi def link ramlVersion            String
hi def link routeInterpolation     String
hi def link ramlInterpolation      Constant
hi def link ramlTodo               Todo
hi def link ramlComment            Comment
hi def link ramlDocumentHeader     PreProc
hi def link ramlDocumentEnd        PreProc
hi def link ramlDirective          Keyword
hi def link ramlNodeProperty       Type
hi def link ramlAnchor             Type
hi def link ramlAlias              Type
hi def link ramlBlock              Operator
hi def link ramlOperator           Operator
hi def link routeParamKey          SpecialChar
hi def link ramlKey                Identifier
hi def link routeKey               SpecialChar
hi def link ramlParameterDelimiter Type
hi def link ramlParameter          Type
hi def link ramlString             String
hi def link ramlStringDelimiter    ramlString
hi def link ramlEscape             SpecialChar
hi def link ramlStringEscape       SpecialChar
hi def link ramlNumber             Number
hi def link ramlConstant           Constant
hi def link ramlTimestamp          Number
hi def link httpVerbs              Statement
hi def link ramlTypes              Type
hi def link ramlDelimiter          Delimiter

let b:current_syntax = "raml"

let &cpo = s:cpo_save
unlet s:cpo_save
