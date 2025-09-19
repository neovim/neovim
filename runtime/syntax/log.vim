" Vim syntax file
" Language:         Generic log file
" Maintainer:       Mao-Yining <https://github.com/mao-yining>
" Former Maintainer:	MTDL9 <https://github.com/MTDL9>
" Latest Revision:  2025-09-16

if exists('b:current_syntax')
  finish
endif

syntax case ignore

" Operators
"---------------------------------------------------------------------------
syn match logOperator display '[;,\?\:\.\<=\>\~\/\@\!$\%&\+\-\|\^(){}\*#]'
syn match logBrackets display '[][]'
syn match logSeparator display '-\{3,}'
syn match logSeparator display '\*\{3,}'
syn match logSeparator display '=\{3,}'
syn match logSeparator display '- - '


" Constants
"---------------------------------------------------------------------------
syn match logNumber       '\<-\?\d\+\>'
syn match logHexNumber    '\<0[xX]\x\+\>'
syn match logHexNumber    '\<\d\x\+\>'
syn match logBinaryNumber '\<0[bB][01]\+\>'
syn match logFloatNumber  '\<\d.\d\+[eE]\?\>'

syn keyword logBoolean    true false
syn keyword logNull       null nil nullptr none

syn region logString      start=/"/ end=/"/ end=/$/ skip=/\\./ contains=logJavaError
" Quoted strings, but no match on quotes like "don't", "plurals' elements"
syn region logString      start=/'\(s \|t \| \w\)\@!/ end=/'/ end=/$/ end=/s / skip=/\\./ contains=logJavaError


" Dates and Times
"---------------------------------------------------------------------------
" Matches 2018-03-12T or 12/03/2018 or 12/Mar/2018 or 27 Nov 2023
syn match logDate '\d\{2,4}[-/ ]\(\d\{2}\|Jan\|Feb\|Mar\|Apr\|May\|Jun\|Jul\|Aug\|Sep\|Oct\|Nov\|Dec\)[-/ ]\d\{2,4}T\?'
" Matches 8 digit numbers at start of line starting with 20
syn match logDate '^20\d\{6}'
" Matches Fri Jan 09 or Feb 11 or Apr  3 or Sun 3
syn keyword logDate Mon Tue Wed Thu Fri Sat Sun Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec nextgroup=logDateDay
syn match logDateDay '\s\{1,2}\d\{1,2}' contained

" Matches 12:09:38 or 00:03:38.129Z or 01:32:12.102938 +0700 or 01:32:12.1234567890 or 21:14:18+11:00
syn match logTime '\d\{2}:\d\{2}:\d\{2}\(\.\d\{2,9}\)\?\(\s\?[-+]\(\d\{1,2\}:\d\{2\}\|\d\{2,4}\)\|Z\)\?\>' nextgroup=logTimeZone,logSysColumns skipwhite

" Follows logTime, matches UTC or PDT 2019 or 2019 EDT
syn match logTimeZone '[A-Z]\{2,5}\>\( \d\{4}\)\?' contained
syn match logTimeZone '\d\{4} [A-Z]\{2,5}\>' contained

" Matches time durations like 1ms or 1y 2d 23ns
syn match logDuration '\(^\|\s\)\@<=\d\+\s*[mn]\?[ywdhms]\(\s\|$\)\@='

" Entities
"---------------------------------------------------------------------------
syn match logUrl        'http[s]\?:\/\/\S\+'
syn match logDomain     '\(^\|\W\)\@<=[[:alnum:]-]\+\(\.[[:alnum:]-]\+\)\+\(\W\|$\)\@='
syn match logUUID       '\w\{8}-\w\{4}-\w\{4}-\w\{4}-\w\{12}'
syn match logMD5        '\<[a-z0-9]\{32}\>'
syn match logIPV4       '\<\d\{1,3}\(\.\d\{1,3}\)\{3}\>'
syn match logIPV6       '\<\x\{1,4}\(:\x\{1,4}\)\{7}\>'
syn match logMacAddress '\<\x\{2}\(:\x\{2}\)\{5}'
syn match logFilePath   '\<\w:\\\f\+'
syn match logFilePath   '[^a-zA-Z0-9"']\@<=/\f\+'

" Java Errors
"---------------------------------------------------------------------------
syn match logJavaError   '\%(\%(Error\|Exception\):\s*\)\zs\w.\{-}\ze\(\\n\|$\)' contained


" Syslog Columns
"---------------------------------------------------------------------------
" Syslog hostname, program and process number columns
syn match logSysColumns '\w\(\w\|\.\|-\)\+ \(\w\|\.\|-\)\+\(\[\d\+\]\)\?:' contains=logOperator,logSysProcess contained
syn match logSysProcess '\(\w\|\.\|-\)\+\(\[\d\+\]\)\?:' contains=logOperator,logNumber,logBrackets contained


" XML Tags
"---------------------------------------------------------------------------
" Simplified matches, not accurate with the spec to avoid false positives
syn match logXmlHeader       /<?\(\w\|-\)\+\(\s\+\w\+\(="[^"]*"\|='[^']*'\)\?\)*?>/ contains=logString,logXmlAttribute,logXmlNamespace
syn match logXmlDoctype      /<!DOCTYPE[^>]*>/ contains=logString,logXmlAttribute,logXmlNamespace
syn match logXmlTag          /<\/\?\(\(\w\|-\)\+:\)\?\(\w\|-\)\+\(\(\n\|\s\)\+\(\(\w\|-\)\+:\)\?\(\w\|-\)\+\(="[^"]*"\|='[^']*'\)\?\)*\s*\/\?>/ contains=logString,logXmlAttribute,logXmlNamespace
syn match logXmlAttribute    contained "\w\+=" contains=logOperator
syn match logXmlAttribute    contained "\(\n\|\s\)\(\(\w\|-\)\+:\)\?\(\w\|-\)\+\(=\)\?" contains=logXmlNamespace,logOperator
syn match logXmlNamespace    contained "\(\w\|-\)\+:" contains=logOperator
syn region logXmlComment     start=/<!--/ end=/-->/
syn match logXmlCData        /<!\[CDATA\[.*\]\]>/
syn match logXmlEntity       /&#\?\w\+;/


" Levels
"---------------------------------------------------------------------------
syn keyword logLevelEmergency EMERGENCY EMERG
syn keyword logLevelAlert ALERT
syn keyword logLevelCritical CRITICAL CRIT FATAL
syn keyword logLevelError ERROR ERR FAILURE SEVERE
syn keyword logLevelWarning WARNING WARN
syn keyword logLevelNotice NOTICE
syn keyword logLevelInfo INFO
syn keyword logLevelDebug DEBUG FINE
syn keyword logLevelTrace TRACE FINER FINEST


" Highlight links
"---------------------------------------------------------------------------
hi def link logNumber Number
hi def link logHexNumber Number
hi def link logBinaryNumber Number
hi def link logFloatNumber Float
hi def link logBoolean Boolean
hi def link logNull Constant
hi def link logString String

hi def link logDate Identifier
hi def link logDateDay Identifier
hi def link logTime Function
hi def link logTimeZone Identifier
hi def link logDuration Identifier

hi def link logUrl Underlined
hi def link logDomain Label
hi def link logUUID Label
hi def link logMD5 Label
hi def link logIPV4 Label
hi def link logIPV6 ErrorMsg
hi def link logMacAddress Label
hi def link logFilePath Conditional

hi def link logJavaError ErrorMsg

hi def link logSysColumns Conditional
hi def link logSysProcess Include

hi def link logXmlHeader Function
hi def link logXmlDoctype Function
hi def link logXmlTag Identifier
hi def link logXmlAttribute Type
hi def link logXmlNamespace Include
hi def link logXmlComment Comment
hi def link logXmlCData String
hi def link logXmlEntity Special

hi def link logOperator Operator
hi def link logBrackets Comment
hi def link logSeparator Comment

hi def link logLevelEmergency ErrorMsg
hi def link logLevelAlert ErrorMsg
hi def link logLevelCritical ErrorMsg
hi def link logLevelError ErrorMsg
hi def link logLevelWarning WarningMsg
hi def link logLevelNotice Character
hi def link logLevelInfo Repeat
hi def link logLevelDebug Debug
hi def link logLevelTrace Comment

let b:current_syntax = 'log'
