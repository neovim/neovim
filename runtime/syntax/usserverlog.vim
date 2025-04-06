" Vim syntax file
" Language:             Innovation Data Processing usserver.log file
" Maintainer:           Rob Owens <rowens@fdrinnovation.com>
" Latest Revision:      2013-09-19

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Date:
syn match usserverlog_Date /\u\l\l \u\l\l\s\{1,2}\d\{1,2} \d\d:\d\d:\d\d \d\d\d\d/
" Msg Types:
syn match usserverlog_MsgD /Msg #\(Agt\|PC\|Srv\)\d\{4,5}D/ nextgroup=usserverlog_Process skipwhite
syn match usserverlog_MsgE /Msg #\(Agt\|PC\|Srv\)\d\{4,5}E/ nextgroup=usserverlog_Process skipwhite
syn match usserverlog_MsgI /Msg #\(Agt\|PC\|Srv\)\d\{4,5}I/ nextgroup=usserverlog_Process skipwhite
syn match usserverlog_MsgW /Msg #\(Agt\|PC\|Srv\)\d\{4,5}W/ nextgroup=usserverlog_Process skipwhite
" Processes:
syn region usserverlog_Process start="(" end=")" contained
" IP Address:
syn match usserverlog_IPaddr /\( \|(\)\zs\d\{1,3}\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}/
" Profile:
syn match usserverlog_Profile /Using default configuration for profile \zs\S\{1,8}\ze/
syn match usserverlog_Profile /Now running profile \zs\S\{1,8}\ze/
syn match usserverlog_Profile /in profile set \zs\S\{1,8}\ze/
syn match usserverlog_Profile /Migrate disk backup from profile \zs\S\{1,8}\ze/
syn match usserverlog_Profile /Using profile prefix for profile \zs\S\{1,8}\ze/
syn match usserverlog_Profile /Add\/update profile \zs\S\{1,8}\ze/
syn match usserverlog_Profile /Profileset=\zs\S\{1,8}\ze,/
syn match usserverlog_Profile /profileset=\zs\S\{1,8}\ze/
syn match usserverlog_Profile /Vault \(disk\|tape\) backup to vault \d\{1,4} from profile \zs\S\{1,8}\ze/
syn match usserverlog_Profile /Profile name \zs\"\S\{1,8}\"/
syn match usserverlog_Profile / Profile: \zs\S\{1,8}/
syn match usserverlog_Profile /  Profile: \zs\S\{1,8}\ze, /
syn match usserverlog_Profile /, profile: \zs\S\{1,8}\ze,/
syn match usserverlog_Profile /Expecting Profile: \zs\S\{1,8}\ze,/
syn match usserverlog_Profile /found Profile: \zs\S\{1,8}\ze,/
syn match usserverlog_Profile /Profile \zs\S\{1,8} \zeis a member of group: /
syn match upstreamlog_Profile /Backup Profile: \zs\S\{1,8}\ze Version date/
syn match upstreamlog_Profile /Backup profile: \zs\S\{1,8}\ze  Version date/
syn match usserverlog_Profile /Full of \zs\S\{1,8}\ze$/
syn match usserverlog_Profile /Incr. of \zs\S\{1,8}\ze$/
syn match usserverlog_Profile /Profile=\zs\S\{1,8}\ze,/
" Target:
syn region usserverlog_Target start="Computer: \zs" end="\ze[\]\)]" 
syn region usserverlog_Target start="Computer name \zs\"" end="\"\ze" 
syn region usserverlog_Target start="Registration add request successful \zs" end="$"
syn region usserverlog_Target start="request to registered name \zs" end=" "
syn region usserverlog_Target start=", sending to \zs" end="$"

hi def link usserverlog_Date	Underlined
hi def link usserverlog_MsgD	Type
hi def link usserverlog_MsgE	Error
hi def link usserverlog_MsgW	Constant
hi def link usserverlog_Process	Statement
hi def link usserverlog_IPaddr	Identifier
hi def link usserverlog_Profile	Identifier
hi def link usserverlog_Target	Identifier

let b:current_syntax = "usserverlog"
