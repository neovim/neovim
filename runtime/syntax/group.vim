" Vim syntax file
" Language:         group(5) user group file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2012-08-05

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   groupBegin          display '^' nextgroup=groupName

syn match   groupName           contained display '[^:]\+'
                                \ nextgroup=groupPasswordColon

syn match   groupPasswordColon  contained display ':'
                                \ nextgroup=groupPassword,groupShadow

syn match   groupPassword       contained display '[^:]*'
                                \ nextgroup=groupGIDColon

syn match   groupShadow         contained display '[x*]' nextgroup=groupGIDColon

syn match   groupGIDColon       contained display ':' nextgroup=groupGID

syn match   groupGID            contained display '\d*'
                                \ nextgroup=groupUserListColon

syn match   groupUserListColon  contained display ':' nextgroup=groupUserList

syn match   groupUserList       contained '[^,]\+'
                                \ nextgroup=groupUserListSep

syn match   groupUserListSep    contained display ',' nextgroup=groupUserList

hi def link groupDelimiter      Normal
hi def link groupName           Identifier
hi def link groupPasswordColon  groupDelimiter
hi def link groupPassword       Number
hi def link groupShadow         Special
hi def link groupGIDColon       groupDelimiter
hi def link groupGID            Number
hi def link groupUserListColon  groupDelimiter
hi def link groupUserList       Identifier
hi def link groupUserListSep    groupDelimiter

let b:current_syntax = "group"

let &cpo = s:cpo_save
unlet s:cpo_save
