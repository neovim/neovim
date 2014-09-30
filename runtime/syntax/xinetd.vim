" Vim syntax file
" Language:         xinetd.conf(5) configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword xinetdTodo          contained TODO FIXME XXX NOTE

syn region  xinetdComment       display oneline start='^\s*#' end='$'
                                \ contains=xinetdTodo,@Spell

syn match   xinetdService       '^\s*service\>'
                                \ nextgroup=xinetdServiceName skipwhite

syn match   xinetdServiceName   contained '\S\+'
                                \ nextgroup=xinetdServiceGroup skipwhite skipnl

syn match   xinetdDefaults      '^\s*defaults'
                                \ nextgroup=xinetdServiceGroup skipwhite skipnl

syn region  xinetdServiceGroup  contained transparent
                                \ matchgroup=xinetdServiceGroupD start='{'
                                \ matchgroup=xinetdServiceGroupD end='}'
                                \ contains=xinetdAttribute,xinetdReqAttribute,
                                \ xinetdDisable

syn keyword xinetdReqAttribute  contained user server protocol
                                \ nextgroup=xinetdStringEq skipwhite

syn keyword xinetdAttribute     contained id group bind
                                \ interface
                                \ nextgroup=xinetdStringEq skipwhite

syn match   xinetdStringEq      contained display '='
                                \ nextgroup=xinetdString skipwhite

syn match   xinetdString        contained display '\S\+'

syn keyword xinetdAttribute     contained type nextgroup=xinetdTypeEq skipwhite

syn match   xinetdTypeEq        contained display '='
                                \ nextgroup=xinetdType skipwhite

syn keyword xinetdType          contained RPC INTERNAL TCPMUX TCPMUXPLUS
                                \ UNLISTED
                                \ nextgroup=xinetdType skipwhite

syn keyword xinetdAttribute     contained flags
                                \ nextgroup=xinetdFlagsEq skipwhite

syn cluster xinetdFlagsC        contains=xinetdFlags,xinetdDeprFlags

syn match   xinetdFlagsEq       contained display '='
                                \ nextgroup=@xinetdFlagsC skipwhite

syn keyword xinetdFlags         contained INTERCEPT NORETRY IDONLY NAMEINARGS
                                \ NODELAY KEEPALIVE NOLIBWRAP SENSOR IPv4 IPv6
                                \ nextgroup=@xinetdFlagsC skipwhite

syn keyword xinetdDeprFlags     contained REUSE nextgroup=xinetdFlagsC skipwhite

syn keyword xinetdDisable       contained disable
                                \ nextgroup=xinetdBooleanEq skipwhite

syn match   xinetdBooleanEq     contained display '='
                                \ nextgroup=xinetdBoolean skipwhite

syn keyword xinetdBoolean       contained yes no

syn keyword xinetdReqAttribute  contained socket_type
                                \ nextgroup=xinetdSocketTypeEq skipwhite

syn match   xinetdSocketTypeEq  contained display '='
                                \ nextgroup=xinetdSocketType skipwhite

syn keyword xinetdSocketType    contained stream dgram raw seqpacket

syn keyword xinetdReqAttribute  contained wait
                                \ nextgroup=xinetdBooleanEq skipwhite

syn keyword xinetdAttribute     contained groups mdns
                                \ nextgroup=xinetdBooleanEq skipwhite

syn keyword xinetdAttribute     contained instances per_source rlimit_cpu
                                \ rlimit_data rlimit_rss rlimit_stack
                                \ nextgroup=xinetdUNumberEq skipwhite

syn match   xinetdUNumberEq     contained display '='
                                \ nextgroup=xinetdUnlimited,xinetdNumber
                                \ skipwhite

syn keyword xinetdUnlimited     contained UNLIMITED

syn match   xinetdNumber        contained display '\<\d\+\>'

syn keyword xinetdAttribute     contained nice
                                \ nextgroup=xinetdSignedNumEq skipwhite

syn match   xinetdSignedNumEq   contained display '='
                                \ nextgroup=xinetdSignedNumber skipwhite

syn match   xinetdSignedNumber  contained display '[+-]\=\d\+\>'

syn keyword xinetdAttribute     contained server_args
                                \ enabled
                                \ nextgroup=xinetdStringsEq skipwhite

syn match   xinetdStringsEq     contained display '='
                                \ nextgroup=xinetdStrings skipwhite

syn match   xinetdStrings       contained display '\S\+'
                                \ nextgroup=xinetdStrings skipwhite

syn keyword xinetdAttribute     contained only_from no_access passenv
                                \ nextgroup=xinetdStringsAdvEq skipwhite

syn match   xinetdStringsAdvEq  contained display '[+-]\=='
                                \ nextgroup=xinetdStrings skipwhite

syn keyword xinetdAttribute     contained access_times
                                \ nextgroup=xinetdTimeRangesEq skipwhite

syn match   xinetdTimeRangesEq  contained display '='
                                \ nextgroup=xinetdTimeRanges skipwhite

syn match   xinetdTimeRanges    contained display
                                \ '\%(0?\d\|1\d\|2[0-3]\):\%(0?\d\|[1-5]\d\)-\%(0?\d\|1\d\|2[0-3]\):\%(0?\d\|[1-5]\d\)'
                                \ nextgroup=xinetdTimeRanges skipwhite

syn keyword xinetdAttribute     contained log_type nextgroup=xinetdLogTypeEq
                                \ skipwhite

syn match   xinetdLogTypeEq     contained display '='
                                \ nextgroup=xinetdLogType skipwhite

syn keyword xinetdLogType       contained SYSLOG nextgroup=xinetdSyslogType
                                \ skipwhite

syn keyword xinetdLogType       contained FILE nextgroup=xinetdLogFile skipwhite

syn keyword xinetdSyslogType    contained daemon auth authpriv user mail lpr
                                \ news uucp ftp local0 local1 local2 local3
                                \ local4 local5 local6 local7
                                \ nextgroup=xinetdSyslogLevel skipwhite

syn keyword xinetdSyslogLevel   contained emerg alert crit err warning notice
                                \ info debug

syn match   xinetdLogFile       contained display '\S\+'
                                \ nextgroup=xinetdLogSoftLimit skipwhite

syn match   xinetdLogSoftLimit  contained display '\<\d\+\>'
                                \ nextgroup=xinetdLogHardLimit skipwhite

syn match   xinetdLogHardLimit  contained display '\<\d\+\>'

syn keyword xinetdAttribute     contained log_on_success
                                \ nextgroup=xinetdLogSuccessEq skipwhite

syn match   xinetdLogSuccessEq  contained display '[+-]\=='
                                \ nextgroup=xinetdLogSuccess skipwhite

syn keyword xinetdLogSuccess    contained PID HOST USERID EXIT DURATION TRAFFIC
                                \ nextgroup=xinetdLogSuccess skipwhite

syn keyword xinetdAttribute     contained log_on_failure
                                \ nextgroup=xinetdLogFailureEq skipwhite

syn match   xinetdLogFailureEq  contained display '[+-]\=='
                                \ nextgroup=xinetdLogFailure skipwhite

syn keyword xinetdLogFailure    contained HOST USERID ATTEMPT
                                \ nextgroup=xinetdLogFailure skipwhite

syn keyword xinetdReqAttribute  contained rpc_version
                                \ nextgroup=xinetdRPCVersionEq skipwhite

syn match   xinetdRPCVersionEq  contained display '='
                                \ nextgroup=xinetdRPCVersion skipwhite

syn match   xinetdRPCVersion    contained display '\d\+\%(-\d\+\)\=\>'

syn keyword xinetdReqAttribute  contained rpc_number port
                                \ nextgroup=xinetdNumberEq skipwhite

syn match   xinetdNumberEq      contained display '='
                                \ nextgroup=xinetdNumber skipwhite

syn keyword xinetdAttribute     contained env nextgroup=xinetdEnvEq skipwhite

syn match   xinetdEnvEq         contained display '+\=='
                                \ nextgroup=xinetdEnvName skipwhite

syn match   xinetdEnvName       contained display '[^=]\+'
                                \ nextgroup=xinetdEnvNameEq

syn match   xinetdEnvNameEq     contained display '=' nextgroup=xinetdEnvValue

syn match   xinetdEnvValue      contained display '\S\+'
                                \ nextgroup=xinetdEnvName skipwhite

syn keyword xinetdAttribute     contained banner banner_success banner_failure
                                \ nextgroup=xinetdPathEq skipwhite

syn keyword xinetdPPAttribute   include includedir
                                \ nextgroup=xinetdPath skipwhite

syn match   xinetdPathEq        contained display '='
                                \ nextgroup=xinetdPath skipwhite

syn match   xinetdPath          contained display '\S\+'

syn keyword xinetdAttribute     contained redirect nextgroup=xinetdRedirectEq
                                \ skipwhite

syn match   xinetdRedirectEq    contained display '='
                                \ nextgroup=xinetdRedirectIP skipwhite

syn match   xinetdRedirectIP    contained display '\S\+'
                                \ nextgroup=xinetdNumber skipwhite

syn keyword xinetdAttribute     contained cps nextgroup=xinetdCPSEq skipwhite

syn match   xinetdCPSEq         contained display '='
                                \ nextgroup=xinetdCPS skipwhite

syn match   xinetdCPS           contained display '\<\d\+\>'
                                \ nextgroup=xinetdNumber skipwhite

syn keyword xinetdAttribute     contained max_load nextgroup=xinetdFloatEq
                                \ skipwhite

syn match   xinetdFloatEq       contained display '='
                                \ nextgroup=xinetdFloat skipwhite

syn match   xinetdFloat         contained display '\d\+\.\d*\|\.\d\+'

syn keyword xinetdAttribute     contained umask nextgroup=xinetdOctalEq
                                \ skipwhite

syn match   xinetdOctalEq       contained display '='
                                \ nextgroup=xinetdOctal,xinetdOctalError
                                \ skipwhite

syn match   xinetdOctal         contained display '\<0\o\+\>'
                                \ contains=xinetdOctalZero
syn match   xinetdOctalZero     contained display '\<0'
syn match   xinetdOctalError    contained display '\<0\o*[89]\d*\>'

syn keyword xinetdAttribute     contained rlimit_as nextgroup=xinetdASEq
                                \ skipwhite

syn match   xinetdASEq          contained display '='
                                \ nextgroup=xinetdAS,xinetdUnlimited
                                \ skipwhite

syn match   xinetdAS            contained display '\d\+' nextgroup=xinetdASMult

syn match   xinetdASMult        contained display '[KM]'

syn keyword xinetdAttribute     contained deny_time nextgroup=xinetdDenyTimeEq
                                \ skipwhite

syn match   xinetdDenyTimeEq    contained display '='
                                \ nextgroup=xinetdDenyTime,xinetdNumber
                                \ skipwhite

syn keyword xinetdDenyTime      contained FOREVER NEVER

hi def link xinetdTodo          Todo
hi def link xinetdComment       Comment
hi def link xinetdService       Keyword
hi def link xinetdServiceName   String
hi def link xinetdDefaults      Keyword
hi def link xinetdServiceGroupD Delimiter
hi def link xinetdReqAttribute  Keyword
hi def link xinetdAttribute     Type
hi def link xinetdEq            Operator
hi def link xinetdStringEq      xinetdEq
hi def link xinetdString        String
hi def link xinetdTypeEq        xinetdEq
hi def link xinetdType          Identifier
hi def link xinetdFlagsEq       xinetdEq
hi def link xinetdFlags         xinetdType
hi def link xinetdDeprFlags     WarningMsg
hi def link xinetdDisable       Special
hi def link xinetdBooleanEq     xinetdEq
hi def link xinetdBoolean       Boolean
hi def link xinetdSocketTypeEq  xinetdEq
hi def link xinetdSocketType    xinetdType
hi def link xinetdUNumberEq     xinetdEq
hi def link xinetdUnlimited     Define
hi def link xinetdNumber        Number
hi def link xinetdSignedNumEq   xinetdEq
hi def link xinetdSignedNumber  xinetdNumber
hi def link xinetdStringsEq     xinetdEq
hi def link xinetdStrings       xinetdString
hi def link xinetdStringsAdvEq  xinetdEq
hi def link xinetdTimeRangesEq  xinetdEq
hi def link xinetdTimeRanges    Number
hi def link xinetdLogTypeEq     xinetdEq
hi def link xinetdLogType       Keyword
hi def link xinetdSyslogType    xinetdType
hi def link xinetdSyslogLevel   Number
hi def link xinetdLogFile       xinetdPath
hi def link xinetdLogSoftLimit  xinetdNumber
hi def link xinetdLogHardLimit  xinetdNumber
hi def link xinetdLogSuccessEq  xinetdEq
hi def link xinetdLogSuccess    xinetdType
hi def link xinetdLogFailureEq  xinetdEq
hi def link xinetdLogFailure    xinetdType
hi def link xinetdRPCVersionEq  xinetdEq
hi def link xinetdRPCVersion    xinetdNumber
hi def link xinetdNumberEq      xinetdEq
hi def link xinetdEnvEq         xinetdEq
hi def link xinetdEnvName       Identifier
hi def link xinetdEnvNameEq     xinetdEq
hi def link xinetdEnvValue      String
hi def link xinetdPPAttribute   PreProc
hi def link xinetdPathEq        xinetdEq
hi def link xinetdPath          String
hi def link xinetdRedirectEq    xinetdEq
hi def link xinetdRedirectIP    String
hi def link xinetdCPSEq         xinetdEq
hi def link xinetdCPS           xinetdNumber
hi def link xinetdFloatEq       xinetdEq
hi def link xinetdFloat         xinetdNumber
hi def link xinetdOctalEq       xinetdEq
hi def link xinetdOctal         xinetdNumber
hi def link xinetdOctalZero     PreProc
hi def link xinetdOctalError    Error
hi def link xinetdASEq          xinetdEq
hi def link xinetdAS            xinetdNumber
hi def link xinetdASMult        PreProc
hi def link xinetdDenyTimeEq    xinetdEq
hi def link xinetdDenyTime      PreProc

let b:current_syntax = "xinetd"

let &cpo = s:cpo_save
unlet s:cpo_save
