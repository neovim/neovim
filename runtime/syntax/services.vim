" Vim syntax file
" Language:             services(5) - Internet network services list
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   servicesBegin     display '^'
                              \ nextgroup=servicesName,servicesComment

syn match   servicesName      contained display '[[:graph:]]\+'
                              \ nextgroup=servicesPort skipwhite

syn match   servicesPort      contained display '\d\+'
                              \ nextgroup=servicesPPDiv,servicesPPDivDepr
                              \ skipwhite

syn match   servicesPPDiv     contained display '/'
                              \ nextgroup=servicesProtocol skipwhite

syn match   servicesPPDivDepr contained display ','
                              \ nextgroup=servicesProtocol skipwhite

syn match   servicesProtocol  contained display '\S\+'
                              \ nextgroup=servicesAliases,servicesComment
                              \ skipwhite

syn match   servicesAliases   contained display '\S\+'
                              \ nextgroup=servicesAliases,servicesComment
                              \ skipwhite

syn keyword servicesTodo      contained TODO FIXME XXX NOTE

syn region  servicesComment   display oneline start='#' end='$'
                              \ contains=servicesTodo,@Spell

hi def link servicesTodo      Todo
hi def link servicesComment   Comment
hi def link servicesName      Identifier
hi def link servicesPort      Number
hi def link servicesPPDiv     Delimiter
hi def link servicesPPDivDepr Error
hi def link servicesProtocol  Type
hi def link servicesAliases   Macro

let b:current_syntax = "services"

let &cpo = s:cpo_save
unlet s:cpo_save
