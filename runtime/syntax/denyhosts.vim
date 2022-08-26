" Vim syntax file
" Language:             denyhosts configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2007-06-25

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword denyhostsTodo
      \ contained
      \ TODO
      \ FIXME
      \ XXX
      \ NOTE

syn case ignore

syn match   denyhostsComment
      \ contained
      \ display
      \ '#.*'
      \ contains=denyhostsTodo,
      \          @Spell

syn match   denyhostsBegin
      \ display
      \ '^'
      \ nextgroup=@denyhostsSetting,
      \           denyhostsComment
      \ skipwhite

syn cluster denyhostsSetting
      \ contains=denyhostsStringSetting,
      \          denyhostsBooleanSetting,
      \          denyhostsPathSetting,
      \          denyhostsNumericSetting,
      \          denyhostsTimespecSetting,
      \          denyhostsFormatSetting,
      \          denyhostsRegexSetting

syn keyword denyhostsStringSetting
      \ contained
      \ ADMIN_EMAIL
      \ SMTP_HOST
      \ SMTP_USERNAME
      \ SMTP_PASSWORD
      \ SMTP_FROM
      \ SMTP_SUBJECT
      \ BLOCK_SERVICE
      \ nextgroup=denyhostsStringDelimiter
      \ skipwhite

syn keyword denyhostsBooleanSetting
      \ contained
      \ SUSPICIOUS_LOGIN_REPORT_ALLOWED_HOSTS
      \ HOSTNAME_LOOKUP
      \ SYSLOG_REPORT
      \ RESET_ON_SUCCESS
      \ SYNC_UPLOAD
      \ SYNC_DOWNLOAD
      \ ALLOWED_HOSTS_HOSTNAME_LOOKUP
      \ nextgroup=denyhostsBooleanDelimiter
      \ skipwhite

syn keyword denyhostsPathSetting
      \ contained
      \ DAEMON_LOG
      \ PLUGIN_DENY
      \ PLUGIN_PURGE
      \ SECURE_LOG
      \ LOCK_FILE
      \ HOSTS_DENY
      \ WORK_DIR
      \ nextgroup=denyhostsPathDelimiter
      \ skipwhite

syn keyword denyhostsNumericSetting
      \ contained
      \ SYNC_DOWNLOAD_THRESHOLD
      \ SMTP_PORT
      \ PURGE_THRESHOLD
      \ DENY_THRESHOLD_INVALID
      \ DENY_THRESHOLD_VALID
      \ DENY_THRESHOLD_ROOT
      \ DENY_THRESHOLD_RESTRICTED
      \ nextgroup=denyhostsNumericDelimiter
      \ skipwhite

syn keyword denyhostsTimespecSetting
      \ contained
      \ DAEMON_SLEEP
      \ DAEMON_PURGE
      \ AGE_RESET_INVALID
      \ AGE_RESET_VALID
      \ AGE_RESET_ROOT
      \ AGE_RESET_RESTRICTED
      \ SYNC_INTERVAL
      \ SYNC_DOWNLOAD_RESILIENCY
      \ PURGE_DENY
      \ nextgroup=denyhostsTimespecDelimiter
      \ skipwhite

syn keyword denyhostsFormatSetting
      \ contained
      \ DAEMON_LOG_TIME_FORMAT
      \ DAEMON_LOG_MESSAGE_FORMAT
      \ SMTP_DATE_FORMAT
      \ nextgroup=denyhostsFormatDelimiter
      \ skipwhite

syn keyword denyhostsRegexSetting
      \ contained
      \ SSHD_FORMAT_REGEX
      \ FAILED_ENTRY_REGEX
      \ FAILED_ENTRY_REGEX2
      \ FAILED_ENTRY_REGEX3
      \ FAILED_ENTRY_REGEX4
      \ FAILED_ENTRY_REGEX5
      \ FAILED_ENTRY_REGEX6
      \ FAILED_ENTRY_REGEX7
      \ USERDEF_FAILED_ENTRY_REGEX
      \ SUCCESSFUL_ENTRY_REGEX
      \ nextgroup=denyhostsRegexDelimiter
      \ skipwhite

syn keyword denyhostURLSetting
      \ contained
      \ SYNC_SERVER
      \ nextgroup=denyhostsURLDelimiter
      \ skipwhite

syn match   denyhostsStringDelimiter
      \ contained
      \ display
      \ '[:=]'
      \ nextgroup=denyhostsString
      \ skipwhite

syn match   denyhostsBooleanDelimiter
      \ contained
      \ display
      \ '[:=]'
      \ nextgroup=@denyhostsBoolean
      \ skipwhite

syn match   denyhostsPathDelimiter
      \ contained
      \ display
      \ '[:=]'
      \ nextgroup=denyhostsPath
      \ skipwhite

syn match   denyhostsNumericDelimiter
      \ contained
      \ display
      \ '[:=]'
      \ nextgroup=denyhostsNumber
      \ skipwhite

syn match   denyhostsTimespecDelimiter
      \ contained
      \ display
      \ '[:=]'
      \ nextgroup=denyhostsTimespec
      \ skipwhite

syn match   denyhostsFormatDelimiter
      \ contained
      \ display
      \ '[:=]'
      \ nextgroup=denyhostsFormat
      \ skipwhite

syn match   denyhostsRegexDelimiter
      \ contained
      \ display
      \ '[:=]'
      \ nextgroup=denyhostsRegex
      \ skipwhite

syn match   denyhostsURLDelimiter
      \ contained
      \ display
      \ '[:=]'
      \ nextgroup=denyhostsURL
      \ skipwhite

syn match   denyhostsString
      \ contained
      \ display
      \ '.\+'

syn cluster denyhostsBoolean
      \ contains=denyhostsBooleanTrue,
      \          denyhostsBooleanFalse

syn match   denyhostsBooleanFalse
      \ contained
      \ display
      \ '.\+'

syn match   denyhostsBooleanTrue
      \ contained
      \ display
      \ '\s*\%(1\|t\%(rue\)\=\|y\%(es\)\=\)\>\s*$'

syn match   denyhostsPath
      \ contained
      \ display
      \ '.\+'

syn match   denyhostsNumber
      \ contained
      \ display
      \ '\d\+\>'

syn match   denyhostsTimespec
      \ contained
      \ display
      \ '\d\+[mhdwy]\>'

syn match   denyhostsFormat
      \ contained
      \ display
      \ '.\+'
      \ contains=denyhostsFormattingExpandos

syn match   denyhostsFormattingExpandos
      \ contained
      \ display
      \ '%.'

syn match   denyhostsRegex
      \ contained
      \ display
      \ '.\+'

" TODO: Perhaps come up with a better regex here?  There should really be a
" library for these kinds of generic regexes, that is, URLs, mail addresses, …
syn match   denyhostsURL
      \ contained
      \ display
      \ '.\+'

hi def link denyhostsTodo               Todo
hi def link denyhostsComment            Comment
hi def link denyhostsSetting            Keyword
hi def link denyhostsStringSetting      denyhostsSetting
hi def link denyhostsBooleanSetting     denyhostsSetting
hi def link denyhostsPathSetting        denyhostsSetting
hi def link denyhostsNumericSetting     denyhostsSetting
hi def link denyhostsTimespecSetting    denyhostsSetting
hi def link denyhostsFormatSetting      denyhostsSetting
hi def link denyhostsRegexSetting       denyhostsSetting
hi def link denyhostURLSetting          denyhostsSetting
hi def link denyhostsDelimiter          Normal
hi def link denyhostsStringDelimiter    denyhostsDelimiter
hi def link denyhostsBooleanDelimiter   denyhostsDelimiter
hi def link denyhostsPathDelimiter      denyhostsDelimiter
hi def link denyhostsNumericDelimiter   denyhostsDelimiter
hi def link denyhostsTimespecDelimiter  denyhostsDelimiter
hi def link denyhostsFormatDelimiter    denyhostsDelimiter
hi def link denyhostsRegexDelimiter     denyhostsDelimiter
hi def link denyhostsURLDelimiter       denyhostsDelimiter
hi def link denyhostsString             String
if exists('g:syntax_booleans_simple') || exists('b:syntax_booleans_simple')
  hi def link denyhostsBoolean          Boolean
  hi def link denyhostsBooleanFalse     denyhostsBoolean
  hi def link denyhostsBooleanTrue      denyhostsBoolean
else
  hi def    denyhostsBooleanTrue        term=bold ctermfg=Green guifg=Green
  hi def    denyhostsBooleanFalse       ctermfg=Red guifg=Red
endif
hi def link denyhostsPath               String
hi def link denyhostsNumber             Number
hi def link denyhostsTimespec           Number
hi def link denyhostsFormat             String
hi def link denyhostsFormattingExpandos Special
hi def link denyhostsRegex              String
hi def link denyhostsURL                String

let b:current_syntax = "denyhosts"

let &cpo = s:cpo_save
unlet s:cpo_save
