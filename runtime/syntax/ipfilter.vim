" ipfilter syntax file
" Language: ipfilter configuration file
" Maintainer: Hendrik Scholz <hendrik@scholz.net>
" Last Change: 2005 Jan 27
"
" http://www.wormulon.net/files/misc/ipfilter.vim
"
" This will also work for OpenBSD pf but there might be some tags that are
" not correctly identified.
" Please send comments to hendrik@scholz.net

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Comment
syn match	IPFComment	/#.*$/	contains=ipfTodo
syn keyword	IPFTodo		TODO XXX FIXME contained

syn keyword IPFActionBlock	block
syn keyword IPFActionPass	pass
syn keyword	IPFProto	tcp udp icmp
syn keyword	IPFSpecial	quick log first
" how could we use keyword for words with '-' ?
syn match	IPFSpecial	/return-rst/
syn match	IPFSpecial	/dup-to/
"syn match	IPFSpecial	/icmp-type unreach/
syn keyword IPFAny		all any
syn match	IPFIPv4		/\d\{1,3}\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}/
syn match	IPFNetmask	/\/\d\+/

" service name constants
syn keyword IPFService	auth bgp domain finger ftp http https ident
syn keyword IPFService	imap irc isakmp kerberos mail nameserver nfs
syn keyword IPFService	nntp ntp pop3 portmap pptp rpcbind rsync smtp
syn keyword IPFService	snmp snmptrap socks ssh sunrpc syslog telnet
syn keyword IPFService	tftp www

" Comment
hi def link IPFComment	Comment
hi def link IPFTodo		Todo

hi def link IPFService	Constant

hi def link IPFAction	Type
hi def link ipfActionBlock	String
hi def link ipfActionPass	Type
hi def link IPFSpecial	Statement
hi def link IPFIPv4		Label
hi def link IPFNetmask	String
hi def link IPFAny		Statement
hi def link IPFProto	Identifier

