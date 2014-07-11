" Vim syntax file
" Language:         setserial(8) configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   setserialBegin      display '^'
                                \ nextgroup=setserialDevice,setserialComment
                                \ skipwhite

syn match   setserialDevice     contained display '\%(/[^ \t/]*\)\+'
                                \ nextgroup=setserialParameter skipwhite

syn keyword setserialParameter  contained port irq baud_base divisor
                                \ close_delay closing_wait rx_trigger
                                \ tx_trigger flow_off flow_on rx_timeout
                                \ nextgroup=setserialNumber skipwhite

syn keyword setserialParameter  contained uart
                                \ nextgroup=setserialUARTType skipwhite

syn keyword setserialParameter  contained autoconfig auto_irq skip_test
                                \ spd_hi spd_vhi spd_shi spd_warp spd_cust
                                \ spd_normal sak fourport session_lockout
                                \ pgrp_lockout hup_notify split_termios
                                \ callout_nohup low_latency
                                \ nextgroup=setserialParameter skipwhite

syn match   setserialParameter  contained display
                                \ '\^\%(auto_irq\|skip_test\|sak\|fourport\)'
                                \ contains=setserialNegation
                                \ nextgroup=setserialParameter skipwhite

syn match   setserialParameter  contained display
                                \ '\^\%(session_lockout\|pgrp_lockout\)'
                                \ contains=setserialNegation
                                \ nextgroup=setserialParameter skipwhite

syn match   setserialParameter  contained display
                                \ '\^\%(hup_notify\|split_termios\)'
                                \ contains=setserialNegation
                                \ nextgroup=setserialParameter skipwhite

syn match   setserialParameter  contained display
                                \ '\^\%(callout_nohup\|low_latency\)'
                                \ contains=setserialNegation
                                \ nextgroup=setserialParameter skipwhite

syn keyword setserialParameter  contained set_multiport
                                \ nextgroup=setserialMultiport skipwhite

syn match   setserialNumber     contained display '\<\d\+\>'
                                \ nextgroup=setserialParameter skipwhite
syn match   setserialNumber     contained display '0x\x\+'
                                \ nextgroup=setserialParameter skipwhite

syn keyword setserialUARTType   contained none

syn match   setserialUARTType   contained display
                                \ '8250\|16[4789]50\|16550A\=\|16650\%(V2\)\='
                                \ nextgroup=setserialParameter skipwhite

syn match   setserialUARTType   contained display '166[59]4'
                                \ nextgroup=setserialParameter skipwhite

syn match   setserialNegation   contained display '\^'

syn match   setserialMultiport  contained '\<port\d\+\>'
                                \ nextgroup=setserialPort skipwhite

syn match   setserialPort       contained display '\<\d\+\>'
                                \ nextgroup=setserialMask skipwhite
syn match   setserialPort       contained display '0x\x\+'
                                \ nextgroup=setserialMask skipwhite

syn match   setserialMask       contained '\<mask\d\+\>'
                                \ nextgroup=setserialBitMask skipwhite

syn match   setserialBitMask    contained display '\<\d\+\>'
                                \ nextgroup=setserialMatch skipwhite
syn match   setserialBitMask    contained display '0x\x\+'
                                \ nextgroup=setserialMatch skipwhite

syn match   setserialMatch      contained '\<match\d\+\>'
                                \ nextgroup=setserialMatchBits skipwhite

syn match   setserialMatchBits  contained display '\<\d\+\>'
                                \ nextgroup=setserialMultiport skipwhite
syn match   setserialMatchBits  contained display '0x\x\+'
                                \ nextgroup=setserialMultiport skipwhite

syn keyword setserialTodo       contained TODO FIXME XXX NOTE

syn region  setserialComment    display oneline start='^\s*#' end='$'
                                \ contains=setserialTodo,@Spell

hi def link setserialTodo       Todo
hi def link setserialComment    Comment
hi def link setserialDevice     Normal
hi def link setserialParameter  Identifier
hi def link setserialNumber     Number
hi def link setserialUARTType   Type
hi def link setserialNegation   Operator
hi def link setserialMultiport  Type
hi def link setserialPort       setserialNumber
hi def link setserialMask       Type
hi def link setserialBitMask    setserialNumber
hi def link setserialMatch      Type
hi def link setserialMatchBits  setserialNumber

let b:current_syntax = "setserial"

let &cpo = s:cpo_save
unlet s:cpo_save
