" Vim syntax file
" Language:             protocols(5) - Internet protocols definition file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   protocolsBegin    display '^'
                              \ nextgroup=protocolsName,protocolsComment

syn match   protocolsName     contained display '[[:graph:]]\+'
                              \ nextgroup=protocolsPort skipwhite

syn match   protocolsPort     contained display '\d\+'
                              \ nextgroup=protocolsAliases,protocolsComment
                              \ skipwhite

syn match   protocolsAliases  contained display '\S\+'
                              \ nextgroup=protocolsAliases,protocolsComment
                              \ skipwhite

syn keyword protocolsTodo     contained TODO FIXME XXX NOTE

syn region  protocolsComment  display oneline start='#' end='$'
                              \ contains=protocolsTodo,@Spell

hi def link protocolsTodo      Todo
hi def link protocolsComment   Comment
hi def link protocolsName      Identifier
hi def link protocolsPort      Number
hi def link protocolsPPDiv     Delimiter
hi def link protocolsPPDivDepr Error
hi def link protocolsProtocol  Type
hi def link protocolsAliases   Macro

let b:current_syntax = "protocols"

let &cpo = s:cpo_save
unlet s:cpo_save
