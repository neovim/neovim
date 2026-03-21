" Vim syntax file
" Language:         Generic log file
" Maintainer:       Mao-Yining <https://github.com/mao-yining>
" Former Maintainer:	MTDL9 <https://github.com/MTDL9>
" Latest Revision:  2025-10-31

if exists('b:current_syntax')
  finish
endif

syntax case ignore

" Operators
"---------------------------------------------------------------------------
syn match logOperator    display '[;,\?\:\.\<=\>\~\/\@\!$\%&\+\-\|\^(){}\*#]'
syn match logBrackets    display '[][]'

" For Visual Separator and Apache CLF
"---------------------------------------------------------------------------
syn match logSeparator   display '-\{3,}\|=\{3,}\|#\{3,}\|\*\{3,}\|<\{3,}\|>\{3,}'
syn match logSeparator   display '- - '

" Strings
" ------------------------------
syn region LogString     start=/"/  end=/"/  end=/$/  skip=/\\./ contains=logJavaError
syn region LogString     start=/`/  end=/`/  end=/$/  skip=/\\./ contains=logJavaError
" Quoted strings, but no match on quotes like `don't`, possessive `s'` and `'s`
syn region LogString     start=/\(s\)\@<!'\(s \|t \)\@!/  end=/'/  end=/$/  skip=/\\./ contains=logJavaError

" Numbers
"---------------------------------------------------------------------------
syn match logNumber      display '\<\d\+\>'
syn match logNumberFloat display '\<\d\+\.\d\+\([eE][-+]\=\d\+\)\=\>'
syn match logNumberFloat display '\<\d\+[eE][-+]\=\d\+\>'
syn match logNumberBin   display '\<0[bB][01]\+\>'
syn match logNumberOct   display '\<0[oO]\o\+\>'
syn match logNumberHex   display '\<0[xX]\x\+\>'

" Possible hex numbers without the '0x' prefix
syn match logNumberHex   display '\<\x\{4,}\>'

" Numbers in Hardware Description Languages e.g. Verilog
" These must be placed after LogString to ensure they take precedence
syn match logNumber      display '\'d\d\+\>'
syn match logNumberBin   display '\'b[01]\+\>'
syn match logNumberOct   display '\'o\o\+\>'
syn match logNumberHex   display '\'h\x\+\>'

" Constants
"---------------------------------------------------------------------------
syn keyword logBoolean   true false
syn keyword logNull      null nil none

" Dates and Times
"---------------------------------------------------------------------------
" MM-DD, DD-MM, MM/DD, DD/MM
syn match logDate        display '\<\d\{2}[-\/]\d\{2}\>'
" YYYY-MM-DD, YYYY/MM/DD
syn match logDate        display '\<\d\{4}[-\/]\d\{2}[-\/]\d\{2}\>'
" DD-MM-YYYY, DD/MM/YYYY
syn match logDate        display '\<\d\{2}[-\/]\d\{2}[-\/]\d\{4}\>'
" First half of RFC3339 e.g. 2023-01-01T
syn match logDate        display '\<\d\{4}-\d\{2}-\d\{2}T'
" 'Dec 31', 'Dec 31, 2023', 'Dec 31 2023'
syn match logDate        display '\<\a\{3} \d\{1,2}\(,\? \d\{4}\)\?\>'
" '31-Dec-2023', '31 Dec 2023'
syn match logDate        display '\<\d\{1,2}[- ]\a\{3}[- ]\d\{4}\>'
" Weekday string
syn keyword logDate      Mon Tue Wed Thu Fri Sat Sun
" Matches 12:09:38 or 00:03:38.129Z or 01:32:12.102938 +0700 or 01:32:12.1234567890 or 21:14:18+11:00
syn match logTime        display '\d\{2}:\d\{2}:\d\{2}\(\.\d\{2,9}\)\?\(\s\?[-+]\(\d\{1,2\}:\d\{2\}\|\d\{2,4}\)\|Z\)\?\>' nextgroup=logTimeZone,logSysColumns skipwhite
" Time zone e.g. Z, +08:00, PST
syn match logTimeZone    display 'Z\|[+-]\d\{2}:\d\{2}\|\a\{3}\>'  contained  skipwhite  nextgroup=logSysColumns
" Matches time durations like 1ms or 1y 2d 23ns 3.14s 1.2e4s 3E+20h
syn match logDuration    display '\(\(\(\d\+d\)\?\d\+h\)\?\d\+m\)\?\d\+\(\.\d\+\)\?[mun]\?s\>'

" Objects
"---------------------------------------------------------------------------
syn match logUrl         display '\<https\?:\/\/\S\+'
syn match logMacAddress  display '\<\x\{2}\([:-]\?\x\{2}\)\{5}\>'
syn match logIPv4        display '\<\d\{1,3}\(\.\d\{1,3}\)\{3}\(\/\d\+\)\?\>'
syn match logIPv6        display '\<\x\{1,4}\(:\x\{1,4}\)\{7}\(\/\d\+\)\?\>'
syn match logUUID        display '\<\x\{8}-\x\{4}-\x\{4}-\x\{4}-\x\{12}\>'
syn match logMD5         display '\<\x\{32}\>'
syn match logSHA         display '\<\(\x\{40}\|\x\{56}\|\x\{64}\|\x\{96}\|\x\{128}\)\>'

" Only highlight a path which is at the start of a line, or preceded by a space
" or an equal sign (for env vars, e.g. PATH=/usr/bin)
" POSIX-style path    e.g. '/var/log/system.log', './run.sh', '../a/b', '~/c'.
syn match logFilePath    display '\(^\|\s\|=\)\zs\(\.\{0,2}\|\~\)\/\f\+\ze'
" Windows drive path  e.g. 'C:\Users\Test'
syn match logFilePath    display '\(^\|\s\|=\)\zs\a:\\\f\+\ze'
" Windows UNC path    e.g. '\\server\share'
syn match logFilePath    display '\(^\|\s\|=\)\zs\\\\\f\+\ze'

" Java Errors
"---------------------------------------------------------------------------
syn match logJavaError    '\%(\%(Error\|Exception\):\s*\)\zs\w.\{-}\ze\(\\n\|$\)' contained

" Syslog Columns
"---------------------------------------------------------------------------
" Syslog hostname, program and process number columns
syn match logSysColumns   '\w\(\w\|\.\|-\)\+ \(\w\|\.\|-\)\+\(\[\d\+\]\)\?:' contains=logOperator,@logLvs,LogSysProcess contained
syn match logSysProcess   '\(\w\|\.\|-\)\+\(\[\d\+\]\)\?:' contains=logOperator,logNumber,logBrackets contained

" XML Tags
"---------------------------------------------------------------------------
" Simplified matches, not accurate with the spec to avoid false positives
syn match logXmlHeader    /<?\(\w\|-\)\+\(\s\+\w\+\(="[^"]*"\|='[^']*'\)\?\)*?>/ contains=logString,logXmlAttribute,logXmlNamespace
syn match logXmlDoctype   /<!DOCTYPE[^>]*>/ contains=logString,logXmlAttribute,logXmlNamespace
syn match logXmlTag       /<\/\?\(\(\w\|-\)\+:\)\?\(\w\|-\)\+\(\(\n\|\s\)\+\(\(\w\|-\)\+:\)\?\(\w\|-\)\+\(="[^"]*"\|='[^']*'\)\?\)*\s*\/\?>/ contains=logString,logXmlAttribute,logXmlNamespace
syn match logXmlAttribute contained "\w\+=" contains=logOperator
syn match logXmlAttribute contained "\(\n\|\s\)\(\(\w\|-\)\+:\)\?\(\w\|-\)\+\(=\)\?" contains=logXmlNamespace,logOperator
syn match logXmlNamespace contained "\(\w\|-\)\+:" contains=logOperator
syn region logXmlComment  start=/<!--/ end=/-->/
syn match logXmlCData     /<!\[CDATA\[.*\]\]>/
syn match logXmlEntity    /&#\?\w\+;/

" Levels
"---------------------------------------------------------------------------
syn keyword logLvFatal      FATAL Fatal fatal
syn keyword logLvEmergency  EMERG[ENCY] Emerg[ency] emerg[ency]
syn keyword logLvAlert      ALERT Alert alert
syn keyword logLvCritical   CRIT[ICAL] Crit[ical] crit[ical]
syn keyword logLvError      E ERR[ORS] Err[ors] err[ors]
syn keyword logLvFail       F FAIL[ED] Fail[ed] fail[ed] FAILURE Failure failure
syn keyword logLvFault      FAULT Fault fault
syn keyword logLvNack       NACK Nack nack NAK Nak nak
syn keyword logLvWarning    W WARN[ING] Warn[ing] warn[ing]
syn keyword logLvBad        BAD Bad bad
syn keyword logLvNotice     NOTICE Notice notice
syn keyword logLvInfo       I INFO Info info
syn keyword logLvDebug      D DEBUG Debug debug DBG Dbg dbg
syn keyword logLvTrace      TRACE Trace trace
syn keyword logLvVerbose    V VERBOSE Verbose verbose
syn keyword logLvPass       PASS[ED] Pass[ed] pass[ed]
syn keyword logLvSuccess    SUCCEED[ED] Succeed[ed] succeed[ed] SUCCESS Success success

" Composite log levels e.g. *_INFO
syn match logLvFatal        display '\<\u\+_FATAL\>'
syn match logLvEmergency    display '\<\u\+_EMERG\(ENCY\)\?\>'
syn match logLvAlert        display '\<\u\+_ALERT\>'
syn match logLvCritical     display '\<\u\+_CRIT\(ICAL\)\?\>'
syn match logLvError        display '\<\u\+_ERR\(OR\)\?\>'
syn match logLvFail         display '\<\u\+_FAIL\(URE\)\?\>'
syn match logLvWarning      display '\<\u\+_WARN\(ING\)\?\>'
syn match logLvNotice       display '\<\u\+_NOTICE\>'
syn match logLvInfo         display '\<\u\+_INFO\>'
syn match logLvDebug        display '\<\u\+_DEBUG\>'
syn match logLvTrace        display '\<\u\+_TRACE\>'

syn cluster logLvs contains=LogLvFatal,LogLvEmergency,LogLvAlert,LogLvCritical,LogLvError,LogLvFail,LogLvFault,LogLvNack,LogLvWarning,LogLvBad,LogLvNotice,LogLvInfo,LogLvDebug,LogLvTrace,LogLvVerbose,LogLvPass,LogLvSuccess

" Highlight links
"---------------------------------------------------------------------------
hi def link logNumber       Number
hi def link logNumberHex    Number
hi def link logNumberBin    Number
hi def link logNumberOct    Number
hi def link logNumberFloat  Float

hi def link logBoolean      Boolean
hi def link logNull         Constant
hi def link logString       String

hi def link logDate         Type
hi def link logTime         Operator
hi def link logTimeZone     Operator
hi def link logDuration     Operator

hi def link logUrl          Underlined
hi def link logIPV4         Underlined
hi def link logIPV6         Underlined
hi def link logMacAddress   Underlined
hi def link logUUID         Label
hi def link logMD5          Label
hi def link logSHA          Label
hi def link logFilePath     Structure

hi def link logJavaError    ErrorMsg

hi def link logSysColumns   Statement
hi def link logSysProcess   Function

hi def link logXmlHeader    Function
hi def link logXmlDoctype   Function
hi def link logXmlTag       Identifier
hi def link logXmlAttribute Type
hi def link logXmlNamespace Include
hi def link logXmlComment   Comment
hi def link logXmlCData     String
hi def link logXmlEntity    Special

hi def link logOperator     Special
hi def link logBrackets     Special
hi def link logSeparator    Comment

hi def link LogLvFatal      ErrorMsg
hi def link LogLvEmergency  ErrorMsg
hi def link LogLvAlert      ErrorMsg
hi def link LogLvCritical   ErrorMsg
hi def link LogLvError      ErrorMsg
hi def link LogLvFail       ErrorMsg
hi def link LogLvFault      ErrorMsg
hi def link LogLvNack       ErrorMsg
hi def link LogLvWarning    WarningMsg
hi def link LogLvBad        WarningMsg
hi def link LogLvNotice     Exception
hi def link LogLvInfo       LogBlue
hi def link LogLvDebug      Debug
hi def link LogLvTrace      Special
hi def link LogLvVerbose    Special
hi def link LogLvPass       LogGreen
hi def link LogLvSuccess    LogGreen

" Custom highlight group
" ------------------------------
hi logGreen ctermfg=lightgreen guifg=#a4c672
hi logBlue  ctermfg=lightblue guifg=#92bcfc


let b:current_syntax = 'log'
