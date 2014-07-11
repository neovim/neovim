" Vim syntax file
" Language:         sensors.conf(5) - libsensors configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword sensorsTodo         contained TODO FIXME XXX NOTE

syn region  sensorsComment      display oneline start='#' end='$'
                                \ contains=sensorsTodo,@Spell


syn keyword sensorsKeyword      bus chip label compute ignore set

syn region  sensorsName         display oneline
                                \ start=+"+ skip=+\\\\\|\\"+ end=+"+
                                \ contains=sensorsNameSpecial
syn match   sensorsName         display '\w\+'

syn match   sensorsNameSpecial  display '\\["\\rnt]'

syn match   sensorsLineContinue '\\$'

syn match   sensorsNumber       display '\d*.\d\+\>'

syn match   sensorsRealWorld    display '@'

syn match   sensorsOperator     display '[+*/-]'

syn match   sensorsDelimiter    display '[()]'

hi def link sensorsTodo         Todo
hi def link sensorsComment      Comment
hi def link sensorsKeyword      Keyword
hi def link sensorsName         String
hi def link sensorsNameSpecial  SpecialChar
hi def link sensorsLineContinue Special
hi def link sensorsNumber       Number
hi def link sensorsRealWorld    Identifier
hi def link sensorsOperator     Normal
hi def link sensorsDelimiter    Normal

let b:current_syntax = "sensors"

let &cpo = s:cpo_save
unlet s:cpo_save
