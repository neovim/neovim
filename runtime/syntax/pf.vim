" pf syntax file
" Language:        OpenBSD packet filter configuration (pf.conf)
" Original Author: Camiel Dobbelaar <cd@sentia.nl>
" Maintainer:      Lauri Tirkkonen <lotheac@iki.fi>
" Last Change:     2018 Jul 16

if exists("b:current_syntax")
  finish
endif

let b:current_syntax = "pf"
setlocal foldmethod=syntax
syn iskeyword @,48-57,_,-,+
syn sync fromstart

syn cluster	pfNotLS		contains=pfTodo,pfVarAssign
syn keyword	pfCmd		anchor antispoof block include match pass queue
syn keyword	pfCmd		queue set table
syn match	pfCmd		/^\s*load\sanchor\>/
syn keyword	pfTodo		TODO XXX contained
syn keyword	pfWildAddr	any no-route urpf-failed self
syn match	pfComment	/#.*$/ contains=pfTodo
syn match	pfCont		/\\$/
syn match	pfErrClose	/}/
syn match	pfIPv4		/\d\{1,3}\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}/
syn match	pfIPv6		/[a-fA-F0-9:]*::[a-fA-F0-9:.]*/
syn match	pfIPv6		/[a-fA-F0-9:]\+:[a-fA-F0-9:]\+:[a-fA-F0-9:.]\+/
syn match	pfNetmask	/\/\d\+/
syn match	pfNum		/[a-zA-Z0-9_:.]\@<!\d\+[a-zA-Z0-9_:.]\@!/
syn match	pfTable		/<\s*[a-zA-Z0-9_:][a-zA-Z0-9_:.-]*\s*>/
syn match	pfVar		/$[a-zA-Z][a-zA-Z0-9_]*/
syn match	pfVarAssign	/^\s*[a-zA-Z][a-zA-Z0-9_]*\s*=/me=e-1
syn region	pfFold1		start=/^#\{1}>/ end=/^#\{1,3}>/me=s-1 transparent fold
syn region	pfFold2		start=/^#\{2}>/ end=/^#\{2,3}>/me=s-1 transparent fold
syn region	pfFold3		start=/^#\{3}>/ end=/^#\{3}>/me=s-1 transparent fold
syn region	pfList		start=/{/ end=/}/ transparent contains=ALLBUT,pfErrClose,@pfNotLS
syn region	pfString	start=/"/ skip=/\\"/ end=/"/ contains=pfIPv4,pfIPv6,pfNetmask,pfTable,pfVar
syn region	pfString	start=/'/ skip=/\\'/ end=/'/ contains=pfIPv4,pfIPv6,pfNetmask,pfTable,pfVar

hi def link pfCmd	Statement
hi def link pfComment	Comment
hi def link pfCont	Statement
hi def link pfErrClose	Error
hi def link pfIPv4	Type
hi def link pfIPv6	Type
hi def link pfNetmask	Constant
hi def link pfNum	Constant
hi def link pfService	Constant
hi def link pfString	String
hi def link pfTable	Identifier
hi def link pfTodo	Todo
hi def link pfVar	Identifier
hi def link pfVarAssign	Identifier
hi def link pfWildAddr	Type

" from OpenBSD src/etc/services r1.95
syn keyword	pfService	802-11-iapp
syn keyword	pfService	Microsoft-SQL-Monitor
syn keyword	pfService	Microsoft-SQL-Server
syn keyword	pfService	NeXTStep
syn keyword	pfService	NextStep
syn keyword	pfService	afpovertcp
syn keyword	pfService	afs3-bos
syn keyword	pfService	afs3-callback
syn keyword	pfService	afs3-errors
syn keyword	pfService	afs3-fileserver
syn keyword	pfService	afs3-kaserver
syn keyword	pfService	afs3-prserver
syn keyword	pfService	afs3-rmtsys
syn keyword	pfService	afs3-update
syn keyword	pfService	afs3-vlserver
syn keyword	pfService	afs3-volser
syn keyword	pfService	amt-redir-tcp
syn keyword	pfService	amt-redir-tls
syn keyword	pfService	amt-soap-http
syn keyword	pfService	amt-soap-https
syn keyword	pfService	asf-rmcp
syn keyword	pfService	at-echo
syn keyword	pfService	at-nbp
syn keyword	pfService	at-rtmp
syn keyword	pfService	at-zis
syn keyword	pfService	auth
syn keyword	pfService	authentication
syn keyword	pfService	bfd-control
syn keyword	pfService	bfd-echo
syn keyword	pfService	bftp
syn keyword	pfService	bgp
syn keyword	pfService	bgpd
syn keyword	pfService	biff
syn keyword	pfService	bootpc
syn keyword	pfService	bootps
syn keyword	pfService	canna
syn keyword	pfService	cddb
syn keyword	pfService	cddbp
syn keyword	pfService	chargen
syn keyword	pfService	chat
syn keyword	pfService	cmd
syn keyword	pfService	cmip-agent
syn keyword	pfService	cmip-man
syn keyword	pfService	comsat
syn keyword	pfService	conference
syn keyword	pfService	conserver
syn keyword	pfService	courier
syn keyword	pfService	csnet-ns
syn keyword	pfService	cso-ns
syn keyword	pfService	cvspserver
syn keyword	pfService	daap
syn keyword	pfService	datametrics
syn keyword	pfService	daytime
syn keyword	pfService	dhcpd-sync
syn keyword	pfService	dhcpv6-client
syn keyword	pfService	dhcpv6-server
syn keyword	pfService	discard
syn keyword	pfService	domain
syn keyword	pfService	echo
syn keyword	pfService	efs
syn keyword	pfService	eklogin
syn keyword	pfService	ekshell
syn keyword	pfService	ekshell2
syn keyword	pfService	epmap
syn keyword	pfService	eppc
syn keyword	pfService	exec
syn keyword	pfService	finger
syn keyword	pfService	ftp
syn keyword	pfService	ftp-data
syn keyword	pfService	git
syn keyword	pfService	gopher
syn keyword	pfService	gre-in-udp
syn keyword	pfService	gre-udp-dtls
syn keyword	pfService	hostname
syn keyword	pfService	hostnames
syn keyword	pfService	hprop
syn keyword	pfService	http
syn keyword	pfService	https
syn keyword	pfService	hunt
syn keyword	pfService	hylafax
syn keyword	pfService	iapp
syn keyword	pfService	icb
syn keyword	pfService	ident
syn keyword	pfService	imap
syn keyword	pfService	imap2
syn keyword	pfService	imap3
syn keyword	pfService	imaps
syn keyword	pfService	ingreslock
syn keyword	pfService	ipp
syn keyword	pfService	iprop
syn keyword	pfService	ipsec-msft
syn keyword	pfService	ipsec-nat-t
syn keyword	pfService	ipx
syn keyword	pfService	irc
syn keyword	pfService	isakmp
syn keyword	pfService	iscsi
syn keyword	pfService	isisd
syn keyword	pfService	iso-tsap
syn keyword	pfService	kauth
syn keyword	pfService	kdc
syn keyword	pfService	kerberos
syn keyword	pfService	kerberos-adm
syn keyword	pfService	kerberos-iv
syn keyword	pfService	kerberos-sec
syn keyword	pfService	kerberos_master
syn keyword	pfService	kf
syn keyword	pfService	kip
syn keyword	pfService	klogin
syn keyword	pfService	kpasswd
syn keyword	pfService	kpop
syn keyword	pfService	krb524
syn keyword	pfService	krb_prop
syn keyword	pfService	krbupdate
syn keyword	pfService	krcmd
syn keyword	pfService	kreg
syn keyword	pfService	kshell
syn keyword	pfService	kx
syn keyword	pfService	l2tp
syn keyword	pfService	ldap
syn keyword	pfService	ldaps
syn keyword	pfService	ldp
syn keyword	pfService	link
syn keyword	pfService	login
syn keyword	pfService	mail
syn keyword	pfService	mdns
syn keyword	pfService	mdnsresponder
syn keyword	pfService	microsoft-ds
syn keyword	pfService	ms-sql-m
syn keyword	pfService	ms-sql-s
syn keyword	pfService	msa
syn keyword	pfService	msp
syn keyword	pfService	mtp
syn keyword	pfService	mysql
syn keyword	pfService	name
syn keyword	pfService	nameserver
syn keyword	pfService	netbios-dgm
syn keyword	pfService	netbios-ns
syn keyword	pfService	netbios-ssn
syn keyword	pfService	netnews
syn keyword	pfService	netplan
syn keyword	pfService	netrjs
syn keyword	pfService	netstat
syn keyword	pfService	netwall
syn keyword	pfService	newdate
syn keyword	pfService	nextstep
syn keyword	pfService	nfs
syn keyword	pfService	nfsd
syn keyword	pfService	nicname
syn keyword	pfService	nnsp
syn keyword	pfService	nntp
syn keyword	pfService	ntalk
syn keyword	pfService	ntp
syn keyword	pfService	null
syn keyword	pfService	openwebnet
syn keyword	pfService	ospf6d
syn keyword	pfService	ospfapi
syn keyword	pfService	ospfd
syn keyword	pfService	photuris
syn keyword	pfService	pop2
syn keyword	pfService	pop3
syn keyword	pfService	pop3pw
syn keyword	pfService	pop3s
syn keyword	pfService	poppassd
syn keyword	pfService	portmap
syn keyword	pfService	postgresql
syn keyword	pfService	postoffice
syn keyword	pfService	pptp
syn keyword	pfService	presence
syn keyword	pfService	printer
syn keyword	pfService	prospero
syn keyword	pfService	prospero-np
syn keyword	pfService	puppet
syn keyword	pfService	pwdgen
syn keyword	pfService	qotd
syn keyword	pfService	quote
syn keyword	pfService	radacct
syn keyword	pfService	radius
syn keyword	pfService	radius-acct
syn keyword	pfService	rdp
syn keyword	pfService	readnews
syn keyword	pfService	remotefs
syn keyword	pfService	resource
syn keyword	pfService	rfb
syn keyword	pfService	rfe
syn keyword	pfService	rfs
syn keyword	pfService	rfs_server
syn keyword	pfService	ripd
syn keyword	pfService	ripng
syn keyword	pfService	rje
syn keyword	pfService	rkinit
syn keyword	pfService	rlp
syn keyword	pfService	routed
syn keyword	pfService	router
syn keyword	pfService	rpc
syn keyword	pfService	rpcbind
syn keyword	pfService	rsync
syn keyword	pfService	rtelnet
syn keyword	pfService	rtsp
syn keyword	pfService	sa-msg-port
syn keyword	pfService	sane-port
syn keyword	pfService	sftp
syn keyword	pfService	shell
syn keyword	pfService	sieve
syn keyword	pfService	silc
syn keyword	pfService	sink
syn keyword	pfService	sip
syn keyword	pfService	smtp
syn keyword	pfService	smtps
syn keyword	pfService	smux
syn keyword	pfService	snmp
syn keyword	pfService	snmp-trap
syn keyword	pfService	snmptrap
syn keyword	pfService	snpp
syn keyword	pfService	socks
syn keyword	pfService	source
syn keyword	pfService	spamd
syn keyword	pfService	spamd-cfg
syn keyword	pfService	spamd-sync
syn keyword	pfService	spooler
syn keyword	pfService	spop3
syn keyword	pfService	ssdp
syn keyword	pfService	ssh
syn keyword	pfService	submission
syn keyword	pfService	sunrpc
syn keyword	pfService	supdup
syn keyword	pfService	supfiledbg
syn keyword	pfService	supfilesrv
syn keyword	pfService	support
syn keyword	pfService	svn
syn keyword	pfService	svrloc
syn keyword	pfService	swat
syn keyword	pfService	syslog
syn keyword	pfService	syslog-tls
syn keyword	pfService	systat
syn keyword	pfService	tacacs
syn keyword	pfService	tacas+
syn keyword	pfService	talk
syn keyword	pfService	tap
syn keyword	pfService	tcpmux
syn keyword	pfService	telnet
syn keyword	pfService	tempo
syn keyword	pfService	tftp
syn keyword	pfService	time
syn keyword	pfService	timed
syn keyword	pfService	timeserver
syn keyword	pfService	timserver
syn keyword	pfService	tsap
syn keyword	pfService	ttylink
syn keyword	pfService	ttytst
syn keyword	pfService	ub-dns-control
syn keyword	pfService	ulistserv
syn keyword	pfService	untp
syn keyword	pfService	usenet
syn keyword	pfService	users
syn keyword	pfService	uucp
syn keyword	pfService	uucp-path
syn keyword	pfService	uucpd
syn keyword	pfService	vnc
syn keyword	pfService	vxlan
syn keyword	pfService	wais
syn keyword	pfService	webster
syn keyword	pfService	who
syn keyword	pfService	whod
syn keyword	pfService	whois
syn keyword	pfService	www
syn keyword	pfService	x400
syn keyword	pfService	x400-snd
syn keyword	pfService	xcept
syn keyword	pfService	xdmcp
syn keyword	pfService	xmpp-bosh
syn keyword	pfService	xmpp-client
syn keyword	pfService	xmpp-server
syn keyword	pfService	z3950
syn keyword	pfService	zabbix-agent
syn keyword	pfService	zabbix-trapper
syn keyword	pfService	zebra
syn keyword	pfService	zebrasrv
