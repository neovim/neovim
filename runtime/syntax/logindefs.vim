" Vim syntax file
" Language:         login.defs(5) configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2010-11-29

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   logindefsBegin          display '^'
                                    \ nextgroup=
                                    \   logindefsComment,
                                    \   @logindefsKeyword
                                    \ skipwhite

syn region  logindefsComment        display oneline start='^\s*#' end='$'
                                    \ contains=logindefsTodo,@Spell

syn keyword logindefsTodo           contained TODO FIXME XXX NOTE

syn cluster logindefsKeyword        contains=
                                    \ logindefsBooleanKeyword,
                                    \ logindefsEncryptKeyword,
                                    \ logindefsNumberKeyword,
                                    \ logindefsPathKeyword,
                                    \ logindefsPathsKeyword,
                                    \ logindefsStringKeyword

syn keyword logindefsBooleanKeyword contained
                                    \ CHFN_AUTH
                                    \ CHSH_AUTH
                                    \ CREATE_HOME
                                    \ DEFAULT_HOME
                                    \ FAILLOG_ENAB
                                    \ LASTLOG_ENAB
                                    \ LOG_OK_LOGINS
                                    \ LOG_UNKFAIL_ENAB
                                    \ MAIL_CHECK_ENAB
                                    \ MD5_CRYPT_ENAB
                                    \ OBSCURE_CHECKS_ENAB
                                    \ PASS_ALWAYS_WARN
                                    \ PORTTIME_CHECKS_ENAB
                                    \ QUOTAS_ENAB
                                    \ SU_WHEEL_ONLY
                                    \ SYSLOG_SG_ENAB
                                    \ SYSLOG_SU_ENAB
                                    \ USERGROUPS_ENAB
                                    \ nextgroup=logindefsBoolean skipwhite

syn keyword logindefsBoolean        contained yes no

syn keyword logindefsEncryptKeyword contained
                                    \ ENCRYPT_METHOD
                                    \ nextgroup=logindefsEncryptMethod skipwhite

syn keyword logindefsEncryptMethod  contained
                                    \ DES
                                    \ MD5
                                    \ SHA256
                                    \ SHA512

syn keyword logindefsNumberKeyword  contained
                                    \ ERASECHAR
                                    \ FAIL_DELAY
                                    \ GID_MAX
                                    \ GID_MIN
                                    \ KILLCHAR
                                    \ LOGIN_RETRIES
                                    \ LOGIN_TIMEOUT
                                    \ MAX_MEMBERS_PER_GROUP
                                    \ PASS_CHANGE_TRIES
                                    \ PASS_MAX_DAYS
                                    \ PASS_MIN_DAYS
                                    \ PASS_WARN_AGE
                                    \ PASS_MAX_LEN
                                    \ PASS_MIN_LEN
                                    \ SHA_CRYPT_MAX_ROUNDS
                                    \ SHA_CRYPT_MIN_ROUNDS
                                    \ SYS_GID_MAX
                                    \ SYS_GID_MIN
                                    \ SYS_UID_MAX
                                    \ SYS_UID_MIN
                                    \ UID_MAX
                                    \ UID_MIN
                                    \ ULIMIT
                                    \ UMASK
                                    \ nextgroup=@logindefsNumber skipwhite

syn cluster logindefsNumber         contains=
                                    \ logindefsDecimal,
                                    \ logindefsHex,
                                    \ logindefsOctal,
                                    \ logindefsOctalError

syn match   logindefsDecimal        contained '\<\d\+\>'

syn match   logindefsHex            contained display '\<0x\x\+\>'

syn match   logindefsOctal          contained display '\<0\o\+\>'
                                    \ contains=logindefsOctalZero
syn match   logindefsOctalZero      contained display '\<0'

syn match   logindefsOctalError     contained display '\<0\o*[89]\d*\>'

syn keyword logindefsPathKeyword    contained
                                    \ ENVIRON_FILE
                                    \ FAKE_SHELL
                                    \ FTMP_FILE
                                    \ HUSHLOGIN_FILE
                                    \ ISSUE_FILE
                                    \ MAIL_DIR
                                    \ MAIL_FILE
                                    \ NOLOGINS_FILE
                                    \ SULOG_FILE
                                    \ TTYTYPE_FILE
                                    \ nextgroup=logindefsPath skipwhite

syn match   logindefsPath           contained '[[:graph:]]\+'

syn keyword logindefsPathsKeyword   contained
                                    \ CONSOLE
                                    \ ENV_PATH
                                    \ ENV_SUPATH
                                    \ MOTD_FILE
                                    \ nextgroup=logindefsPaths skipwhite

syn match   logindefsPaths          contained '[^:]\+'
                                    \ nextgroup=logindefsPathDelim

syn match   logindefsPathDelim      contained ':' nextgroup=logindefsPaths

syn keyword logindefsStringKeyword  contained
                                    \ CHFN_RESTRICT
                                    \ CONSOLE_GROUPS
                                    \ ENV_HZ
                                    \ ENV_TZ
                                    \ LOGIN_STRING
                                    \ SU_NAME
                                    \ TTYGROUP
                                    \ TTYPERM
                                    \ USERDEL_CMD
                                    \ nextgroup=logindefsString skipwhite

syn match   logindefsString         contained '[[:graph:]]\+'

hi def link logindefsComment        Comment
hi def link logindefsTodo           Todo
hi def link logindefsKeyword        Keyword
hi def link logindefsBooleanKeyword logindefsKeyword
hi def link logindefsEncryptKeyword logindefsKeyword
hi def link logindefsNumberKeyword  logindefsKeyword
hi def link logindefsPathKeyword    logindefsKeyword
hi def link logindefsPathsKeyword   logindefsKeyword
hi def link logindefsStringKeyword  logindefsKeyword
hi def link logindefsBoolean        Boolean
hi def link logindefsEncryptMethod  Type
hi def link logindefsNumber         Number
hi def link logindefsDecimal        logindefsNumber
hi def link logindefsHex            logindefsNumber
hi def link logindefsOctal          logindefsNumber
hi def link logindefsOctalZero      PreProc
hi def link logindefsOctalError     Error
hi def link logindefsPath           String
hi def link logindefsPaths          logindefsPath
hi def link logindefsPathDelim      Delimiter
hi def link logindefsString         String

let b:current_syntax = "logindefs"

let &cpo = s:cpo_save
unlet s:cpo_save
