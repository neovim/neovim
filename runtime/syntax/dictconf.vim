" Vim syntax file
" Language:             dict(1) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword dictconfTodo        contained TODO FIXME XXX NOTE

syn region  dictconfComment     display oneline start='#' end='$'
                                \ contains=dictconfTodo,@Spell

syn match   dictconfBegin       display '^'
                                \ nextgroup=dictconfKeyword,dictconfComment
                                \ skipwhite

syn keyword dictconfKeyword     contained server
                                \ nextgroup=dictconfServer skipwhite

syn keyword dictconfKeyword     contained pager
                                \ nextgroup=dictconfPager

syn match   dictconfServer      contained display
                                \ '[[:alnum:]_/.*-][[:alnum:]_/.*-]*'
                                \ nextgroup=dictconfServerOptG skipwhite

syn region  dictconfServer      contained display oneline
                                \ start=+"+ skip=+""+ end=+"+
                                \ nextgroup=dictconfServerOptG skipwhite

syn region  dictconfServerOptG  contained transparent
                                \ matchgroup=dictconfServerOptsD start='{'
                                \ matchgroup=dictconfServerOptsD end='}'
                                \ contains=dictconfServerOpts,dictconfComment

syn keyword dictconfServerOpts  contained port
                                \ nextgroup=dictconfNumber skipwhite

syn keyword dictconfServerOpts  contained user
                                \ nextgroup=dictconfUsername skipwhite

syn match   dictconfUsername    contained display
                                \ '[[:alnum:]_/.*-][[:alnum:]_/.*-]*'
                                \ nextgroup=dictconfSecret skipwhite
syn region  dictconfUsername    contained display oneline
                                \ start=+"+ skip=+""+ end=+"+
                                \ nextgroup=dictconfSecret skipwhite

syn match   dictconfSecret      contained display
                                \ '[[:alnum:]_/.*-][[:alnum:]_/.*-]*'
syn region  dictconfSecret      contained display oneline
                                \ start=+"+ skip=+""+ end=+"+

syn match   dictconfNumber      contained '\<\d\+\>'

syn match   dictconfPager       contained display
                                \ '[[:alnum:]_/.*-][[:alnum:]_/.*-]*'
syn region  dictconfPager       contained display oneline
                                \ start=+"+ skip=+""+ end=+"+

hi def link dictconfTodo        Todo
hi def link dictconfComment     Comment
hi def link dictconfKeyword     Keyword
hi def link dictconfServer      String
hi def link dictconfServerOptsD Delimiter
hi def link dictconfServerOpts  Identifier
hi def link dictconfUsername    String
hi def link dictconfSecret      Special
hi def link dictconfNumber      Number
hi def link dictconfPager       String

let b:current_syntax = "dictconf"

let &cpo = s:cpo_save
unlet s:cpo_save
