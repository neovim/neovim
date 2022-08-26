" Vim syntax file
" Language:		fetchmail(1) RC File
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Latest Revision:	2022 Jul 02

" Version 6.4.3

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword fetchmailTodo	contained FIXME TODO XXX NOTE

syn region  fetchmailComment	start='#' end='$' contains=fetchmailTodo,@Spell

syn match   fetchmailNumber	display '\<\d\+\>'

syn region  fetchmailString	start=+"+ skip=+\\\\\|\\"+ end=+"+
				\ contains=fetchmailStringEsc
syn region  fetchmailString	start=+'+ skip=+\\\\\|\\'+ end=+'+
				\ contains=fetchmailStringEsc

syn match   fetchmailStringEsc	contained '\\\([ntb]\|0\d*\|x\x\+\)'

syn region  fetchmailKeyword	transparent matchgroup=fetchmailKeyword
				\ start='\<poll\|skip\|defaults\>'
				\ end='\<poll\|skip\|defaults\>'
				\ contains=ALLBUT,fetchmailOptions,fetchmailSet

syn keyword fetchmailServerOpts contained via proto[col] local[domains] port
				\ service auth[enticate] timeout envelope
				\ qvirtual aka interface monitor plugin plugout
				\ dns checkalias uidl interval tracepolls
				\ principal esmtpname esmtppassword
" removed in 6.3.0
syn keyword fetchmailServerOpts contained netsec
syn match   fetchmailServerOpts contained '\<bad-header\>'
syn match   fetchmailServerOpts contained '\<no\_s\+\(envelope\|dns\|checkalias\|uidl\)'

syn keyword fetchmailUserOpts	contained user[name] is to pass[word] ssl
				\ sslcert sslcertck sslcertfile sslcertpath
				\ sslfingerprint sslkey sslproto folder
				\ smtphost fetchdomains smtpaddress smtpname
				\ antispam mda bsmtp preconnect postconnect
				\ keep flush limitflush fetchall rewrite
				\ stripcr forcecr pass8bits dropstatus
				\ dropdelivered mimedecode idle limit warnings
				\ batchlimit fetchlimit fetchsizelimit
				\ fastuidl expunge properties
				\ sslcommonname
syn match   fetchmailUserOpts	contained '\<no\_s\+\(sslcertck\|keep\|flush\|fetchall\|rewrite\|stripcr\|forcecr\|pass8bits\|dropstatus\|dropdelivered\|mimedecode\|idle\)'

syn keyword fetchmailSpecial	contained here there

syn keyword fetchmailNoise	and with has wants options
syn match   fetchmailNoise	display '[:;,]'

syn keyword fetchmailSet	nextgroup=fetchmailOptions skipwhite skipnl set

syn keyword fetchmailOptions	daemon postmaster bouncemail spambounce
				\ softbounce logfile pidfile idfile syslog properties
syn match   fetchmailOptions	'\<no\_s\+\(bouncemail\|spambounce\|softbounce\|syslog\)'

hi def link fetchmailComment	Comment
hi def link fetchmailTodo	Todo
hi def link fetchmailNumber	Number
hi def link fetchmailString	String
hi def link fetchmailStringEsc	SpecialChar
hi def link fetchmailKeyword	Keyword
hi def link fetchmailServerOpts Identifier
hi def link fetchmailUserOpts	Identifier
hi def link fetchmailSpecial	Special
hi def link fetchmailSet	Keyword
hi def link fetchmailOptions	Identifier

let b:current_syntax = "fetchmail"

let &cpo = s:cpo_save
unlet s:cpo_save
