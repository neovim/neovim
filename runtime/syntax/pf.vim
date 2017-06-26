" pf syntax file
" Language:        OpenBSD packet filter configuration (pf.conf)
" Original Author: Camiel Dobbelaar <cd@sentia.nl>
" Maintainer:      Lauri Tirkkonen <lotheac@iki.fi>
" Last Change:     2016 Jul 06

if exists("b:current_syntax")
  finish
endif

setlocal foldmethod=syntax
syn iskeyword @,48-57,_,-,+
syn sync fromstart

syn cluster	pfNotLS		contains=pfTodo,pfVarAssign
syn keyword	pfCmd		anchor antispoof block include match pass queue
syn keyword	pfCmd		queue set table
syn match	pfCmd		/^\s*load\sanchor\>/
syn keyword	pfTodo		TODO XXX contained
syn keyword	pfWildAddr	all any
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

syn keyword	pfService	802-11-iapp Microsoft-SQL-Monitor
syn keyword	pfService	Microsoft-SQL-Server NeXTStep NextStep
syn keyword	pfService	afpovertcp afs3-bos afs3-callback afs3-errors
syn keyword	pfService	afs3-fileserver afs3-kaserver afs3-prserver
syn keyword	pfService	afs3-rmtsys afs3-update afs3-vlserver
syn keyword	pfService	afs3-volser amt-redir-tcp amt-redir-tls
syn keyword	pfService	amt-soap-http amt-soap-https asf-rmcp at-echo
syn keyword	pfService	at-nbp at-rtmp at-zis auth authentication
syn keyword	pfService	bfd-control bfd-echo bftp bgp bgpd biff bootpc
syn keyword	pfService	bootps canna cddb cddbp chargen chat cmd
syn keyword	pfService	cmip-agent cmip-man comsat conference
syn keyword	pfService	conserver courier csnet-ns cso-ns cvspserver
syn keyword	pfService	daap datametrics daytime dhcpd-sync
syn keyword	pfService	dhcpv6-client dhcpv6-server discard domain
syn keyword	pfService	echo efs eklogin ekshell ekshell2 epmap eppc
syn keyword	pfService	exec finger ftp ftp-data git gopher hostname
syn keyword	pfService	hostnames hprop http https hunt hylafax iapp
syn keyword	pfService	icb ident imap imap2 imap3 imaps ingreslock
syn keyword	pfService	ipp iprop ipsec-msft ipsec-nat-t ipx irc
syn keyword	pfService	isakmp iscsi isisd iso-tsap kauth kdc kerberos
syn keyword	pfService	kerberos-adm kerberos-iv kerberos-sec
syn keyword	pfService	kerberos_master kf kip klogin kpasswd kpop
syn keyword	pfService	krb524 krb_prop krbupdate krcmd kreg kshell kx
syn keyword	pfService	l2tp ldap ldaps ldp link login mail mdns
syn keyword	pfService	mdnsresponder microsoft-ds ms-sql-m ms-sql-s
syn keyword	pfService	msa msp mtp mysql name nameserver netbios-dgm
syn keyword	pfService	netbios-ns netbios-ssn netnews netplan netrjs
syn keyword	pfService	netstat netwall newdate nextstep nfs nfsd
syn keyword	pfService	nicname nnsp nntp ntalk ntp null openwebnet
syn keyword	pfService	ospf6d ospfapi ospfd photuris pop2 pop3 pop3pw
syn keyword	pfService	pop3s poppassd portmap postgresql postoffice
syn keyword	pfService	pptp presence printer prospero prospero-np
syn keyword	pfService	puppet pwdgen qotd quote radacct radius
syn keyword	pfService	radius-acct rdp readnews remotefs resource rfb
syn keyword	pfService	rfe rfs rfs_server ripd ripng rje rkinit rlp
syn keyword	pfService	routed router rpc rpcbind rsync rtelnet rtsp
syn keyword	pfService	sa-msg-port sane-port sftp shell sieve silc
syn keyword	pfService	sink sip smtp smtps smux snmp snmp-trap
syn keyword	pfService	snmptrap snpp socks source spamd spamd-cfg
syn keyword	pfService	spamd-sync spooler spop3 ssdp ssh submission
syn keyword	pfService	sunrpc supdup supfiledbg supfilesrv support
syn keyword	pfService	svn svrloc swat syslog syslog-tls systat
syn keyword	pfService	tacacs tacas+ talk tap tcpmux telnet tempo
syn keyword	pfService	tftp time timed timeserver timserver tsap
syn keyword	pfService	ttylink ttytst ub-dns-control ulistserv untp
syn keyword	pfService	usenet users uucp uucp-path uucpd vnc vxlan
syn keyword	pfService	wais webster who whod whois www x400 x400-snd
syn keyword	pfService	xcept xdmcp xmpp-bosh xmpp-client xmpp-server
syn keyword	pfService	z3950 zabbix-agent zabbix-trapper zebra
syn keyword	pfService	zebrasrv

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

let b:current_syntax = "pf"
