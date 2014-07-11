" Vim syntax file
" Language:         dictd(8) configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword dictdconfTodo        contained TODO FIXME XXX NOTE

syn region  dictdconfComment    display oneline start='#' end='$'
                                \ contains=dictdconfTodo,dictdconfSpecialC,
                                \ @Spell

syn keyword dictdconfSpecialC   LASTLINE

syn match   dictdconfBegin      display '^'
                                \ nextgroup=dictdconfKeyword,dictdconfComment
                                \ skipwhite

syn keyword dictdconfKeyword    contained access
                                \ nextgroup=dictdconfAccessG skipwhite

syn region  dictdconfAccessG    contained transparent
                                \ matchgroup=dictdconfDelimiter start='{'
                                \ matchgroup=dictdconfDelimiter end='}'
                                \ contains=dictdconfAccess,dictdconfComment

syn keyword dictdconfAccess     contained allow deny authonly user
                                \ nextgroup=dictdconfString skipwhite

syn keyword dictdconfKeyword    contained database
                                \ nextgroup=dictdconfDatabase skipwhite

syn match   dictdconfDatabase   contained display
                                \ '[[:alnum:]_/.*-][[:alnum:]_/.*-]*'
                                \ nextgroup=dictdconfSpecG skipwhite
syn region  dictdconfDatabase   contained display oneline
                                \ start=+"+ skip=+""\|\\\\\|\\"+ end=+"+
                                \ nextgroup=dictdconfSpecG skipwhite

syn region  dictdconfSpecG      contained transparent
                                \ matchgroup=dictdconfDelimiter start='{'
                                \ matchgroup=dictdconfDelimiter end='}'
                                \ contains=dictdconfSpec,dictdconfAccess,
                                \ dictdconfComment

syn keyword dictdconfSpec       contained data index index_suffix index_word
                                \ filter prefilter postfilter name info
                                \ disable_strat
                                \ nextgroup=dictdconfString skipwhite

syn keyword dictdconfSpec       contained invisible

syn keyword dictdconfKeyword    contained database_virtual
                                \ nextgroup=dictdconfVDatabase skipwhite

syn match   dictdconfVDatabase  contained display
                                \ '[[:alnum:]_/.*-][[:alnum:]_/.*-]*'
                                \ nextgroup=dictdconfVSpecG skipwhite
syn region  dictdconfVDatabase   contained display oneline
                                \ start=+"+ skip=+""\|\\\\\|\\"+ end=+"+
                                \ nextgroup=dictdconfVSpecG skipwhite

syn region  dictdconfVSpecG     contained transparent
                                \ matchgroup=dictdconfDelimiter start='{'
                                \ matchgroup=dictdconfDelimiter end='}'
                                \ contains=dictdconfVSpec,dictdconfAccess,
                                \ dictdconfComment

syn keyword dictdconfVSpec      contained name info database_list disable_strat
                                \ nextgroup=dictdconfString skipwhite

syn keyword dictdconfVSpec      contained invisible

syn keyword dictdconfKeyword    contained database_plugin
                                \ nextgroup=dictdconfPDatabase skipwhite

syn match   dictdconfPDatabase  contained display
                                \ '[[:alnum:]_/.*-][[:alnum:]_/.*-]*'
                                \ nextgroup=dictdconfPSpecG skipwhite
syn region  dictdconfPDatabase   contained display oneline
                                \ start=+"+ skip=+""\|\\\\\|\\"+ end=+"+
                                \ nextgroup=dictdconfPSpecG skipwhite

syn region  dictdconfPSpecG     contained transparent
                                \ matchgroup=dictdconfDelimiter start='{'
                                \ matchgroup=dictdconfDelimiter end='}'
                                \ contains=dictdconfPSpec,dictdconfAccess,
                                \ dictdconfComment

syn keyword dictdconfPSpec      contained name info plugin data disable_strat
                                \ nextgroup=dictdconfString skipwhite

syn keyword dictdconfPSpec      contained invisible

syn keyword dictdconfKeyword    contained database_exit

syn keyword dictdconfKeyword    contained site
                                \ nextgroup=dictdconfString skipwhite

syn keyword dictdconfKeyword    contained user
                                \ nextgroup=dictdconfUsername skipwhite

syn match   dictdconfUsername   contained display
                                \ '[[:alnum:]_/.*-][[:alnum:]_/.*-]*'
                                \ nextgroup=dictdconfSecret skipwhite
syn region  dictdconfUsername   contained display oneline
                                \ start=+"+ skip=+""+ end=+"+
                                \ nextgroup=dictdconfSecret skipwhite

syn match   dictdconfSecret     contained display
                                \ '[[:alnum:]_/.*-][[:alnum:]_/.*-]*'
syn region  dictdconfSecret     contained display oneline
                                \ start=+"+ skip=+""+ end=+"+

syn match   dictdconfString     contained display
                                \ '[[:alnum:]_/.*-][[:alnum:]_/.*-]*'
syn region  dictdconfString     contained display oneline
                                \ start=+"+ skip=+""\|\\\\\|\\"+ end=+"+

hi def link dictdconfTodo       Todo
hi def link dictdconfComment    Comment
hi def link dictdconfSpecialC   Special
hi def link dictdconfKeyword    Keyword
hi def link dictdconfIdentifier Identifier
hi def link dictdconfAccess     dictdconfIdentifier
hi def link dictdconfDatabase   dictdconfString
hi def link dictdconfSpec       dictdconfIdentifier
hi def link dictdconfVDatabase  dictdconfDatabase
hi def link dictdconfVSpec      dictdconfSpec
hi def link dictdconfPDatabase  dictdconfDatabase
hi def link dictdconfPSpec      dictdconfSpec
hi def link dictdconfUsername   dictdconfString
hi def link dictdconfSecret     Special
hi def link dictdconfString     String
hi def link dictdconfDelimiter  Delimiter

let b:current_syntax = "dictdconf"

let &cpo = s:cpo_save
unlet s:cpo_save
