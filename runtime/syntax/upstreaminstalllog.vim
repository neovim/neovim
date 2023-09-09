" Vim syntax file
" Language:             Innovation Data Processing UPSTREAMInstall.log file
" Maintainer:           Rob Owens <rowens@fdrinnovation.com>
" Latest Revision:      2013-06-17

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Date:
syn match upstreaminstalllog_Date /\u\l\l \u\l\l\s\{1,2}\d\{1,2} \d\d:\d\d:\d\d \d\d\d\d/
" Msg Types:
syn match upstreaminstalllog_MsgD /Msg #MSI\d\{4,5}D/
syn match upstreaminstalllog_MsgE /Msg #MSI\d\{4,5}E/
syn match upstreaminstalllog_MsgI /Msg #MSI\d\{4,5}I/
syn match upstreaminstalllog_MsgW /Msg #MSI\d\{4,5}W/
" IP Address:
syn match upstreaminstalllog_IPaddr / \d\{1,3}\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}/

hi def link upstreaminstalllog_Date	Underlined
hi def link upstreaminstalllog_MsgD	Type
hi def link upstreaminstalllog_MsgE	Error
hi def link upstreaminstalllog_MsgW	Constant
hi def link upstreaminstalllog_IPaddr	Identifier

let b:current_syntax = "upstreaminstalllog"
