" Vim syntax file
" Maintainer:	Thilo Six
" Contact:	vim-foo@xk2c-foo.de
"		:3s+-foo++g
" Description:	highlight dnsmasq configuration files
" File:		runtime/syntax/dnsmasq.vim
" Version:	2.70
" Last Change:	2014 Apr 30
" Modeline:	vim: ts=8:sw=2:sts=2:
"
" License:	VIM License
"		Vim is Charityware, see ":help Uganda"
"
" Options:	You might want to add this to your vimrc:
"
"		if &background == "dark"
"		    let dnsmasq_backrgound_light = 0
"		else
"		    let dnsmasq_backrgound_light = 1
"		endif
"

" For version 5.x: Clear all syntax items
if v:version < 600
    syntax clear
elseif exists("b:current_syntax") || &compatible
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

if !exists("b:dnsmasq_backrgound_light")
    if exists("dnsmasq_backrgound_light")
	let b:dnsmasq_backrgound_light = dnsmasq_backrgound_light
    else
	let b:dnsmasq_backrgound_light = 0
    endif
endif


" case on
syn case match

syn match   DnsmasqValues   "=.*"hs=s+1 contains=DnsmasqComment,DnsmasqSpecial
syn match   DnsmasqSpecial  display '=\|@\|,\|!\|:'	  nextgroup=DnsmasqValues
syn match   DnsmasqSpecial  "#"

syn match   DnsmasqIPv4	    "\<\(\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\.\)\{3\}\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\>"	nextgroup=DnsmasqSubnet2,DnsmasqRange
syn match   DnsmasqSubnet   "\<255.\(\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\.\)\{2\}\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\>"
syn match   DnsmasqSubnet2  contained "\/\([0-4]\?[0-9]\)\>"
syn match   DnsmasqRange    contained "-"
syn match   DnsmasqMac	    "\<\(\x\x\?:\)\{5}\x\x\?"

syn match   DnsmasqTime	    "\<\(\d\{1,3}\)[hm]\>"

" String
syn match   DnsmasqString   "\".*\""  contains=@Spell
syn match   DnsmasqString   "'.*'"    contains=@Spell

" Comments
syn keyword DnsmasqTodo	    FIXME TODO XXX NOTE contained
syn match   DnsmasqComment  "\(^\|\s\+\)#.*$"   contains=@Spell,DnsmasqTodo

" highlight trailing spaces
syn match   DnsmasqTrailSpace	   "[ \t]\+$"
syn match   DnsmasqTrailSpace	   "[ \t]\+$" containedin=ALL

syn match DnsmasqKeywordSpecial    "\<set\>:"me=e-1
syn match DnsmasqKeywordSpecial    "\<tag\>:"me=e-1
syn match DnsmasqKeywordSpecial    ",\<static\>"hs=s+1	  contains=DnsmasqSpecial
syn match DnsmasqKeywordSpecial    ",\<infinite\>"hs=s+1  contains=DnsmasqSpecial
syn match DnsmasqKeywordSpecial    "\<encap\>:"me=e-1
syn match DnsmasqKeywordSpecial    "\<interface\>:"me=e-1
syn match DnsmasqKeywordSpecial    "\<vi-encap\>:"me=e-1
syn match DnsmasqKeywordSpecial    "\<net\>:"me=e-1
syn match DnsmasqKeywordSpecial    "\<vendor\>:"me=e-1
syn match DnsmasqKeywordSpecial    "\<opt\>:"me=e-1
syn match DnsmasqKeywordSpecial    "\<option\>:"me=e-1
syn match DnsmasqKeywordSpecial    ",\<ignore\>"hs=s+1	  contains=DnsmasqSpecial
syn match DnsmasqKeywordSpecial    "\<id\>:"me=e-1

syn match DnsmasqKeyword    "^\s*add-mac\>"
syn match DnsmasqKeyword    "^\s*add-subnet\>"
syn match DnsmasqKeyword    "^\s*addn-hosts\>"
syn match DnsmasqKeyword    "^\s*address\>"
syn match DnsmasqKeyword    "^\s*alias\>"
syn match DnsmasqKeyword    "^\s*all-servers\>"
syn match DnsmasqKeyword    "^\s*auth-zone\>"
syn match DnsmasqKeyword    "^\s*bind-dynamic\>"
syn match DnsmasqKeyword    "^\s*bind-interfaces\>"
syn match DnsmasqKeyword    "^\s*bogus-nxdomain\>"
syn match DnsmasqKeyword    "^\s*bogus-priv\>"
syn match DnsmasqKeyword    "^\s*bootp-dynamic\>"
syn match DnsmasqKeyword    "^\s*bridge-interface\>"
syn match DnsmasqKeyword    "^\s*cache-size\>"
syn match DnsmasqKeyword    "^\s*clear-on-reload\>"
syn match DnsmasqKeyword    "^\s*cname\>"
syn match DnsmasqKeyword    "^\s*conf-dir\>"
syn match DnsmasqKeyword    "^\s*conf-file\>"
syn match DnsmasqKeyword    "^\s*conntrack\>"
syn match DnsmasqKeyword    "^\s*dhcp-alternate-port\>"
syn match DnsmasqKeyword    "^\s*dhcp-authoritative\>"
syn match DnsmasqKeyword    "^\s*dhcp-boot\>"
syn match DnsmasqKeyword    "^\s*dhcp-broadcast\>"
syn match DnsmasqKeyword    "^\s*dhcp-circuitid\>"
syn match DnsmasqKeyword    "^\s*dhcp-client-update\>"
syn match DnsmasqKeyword    "^\s*dhcp-duid\>"
syn match DnsmasqKeyword    "^\s*dhcp-fqdn\>"
syn match DnsmasqKeyword    "^\s*dhcp-generate-names\>"
syn match DnsmasqKeyword    "^\s*dhcp-host\>"
syn match DnsmasqKeyword    "^\s*dhcp-hostsfile\>"
syn match DnsmasqKeyword    "^\s*dhcp-ignore\>"
syn match DnsmasqKeyword    "^\s*dhcp-ignore-names\>"
syn match DnsmasqKeyword    "^\s*dhcp-lease-max\>"
syn match DnsmasqKeyword    "^\s*dhcp-leasefile\>"
syn match DnsmasqKeyword    "^\s*dhcp-luascript\>"
syn match DnsmasqKeyword    "^\s*dhcp-mac\>"
syn match DnsmasqKeyword    "^\s*dhcp-match\>"
syn match DnsmasqKeyword    "^\s*dhcp-no-override\>"
syn match DnsmasqKeyword    "^\s*dhcp-option\>"
syn match DnsmasqKeyword    "^\s*dhcp-option-force\>"
syn match DnsmasqKeyword    "^\s*dhcp-optsfile\>"
syn match DnsmasqKeyword    "^\s*dhcp-proxy\>"
syn match DnsmasqKeyword    "^\s*dhcp-range\>"
syn match DnsmasqKeyword    "^\s*dhcp-relay\>"
syn match DnsmasqKeyword    "^\s*dhcp-remoteid\>"
syn match DnsmasqKeyword    "^\s*dhcp-script\>"
syn match DnsmasqKeyword    "^\s*dhcp-scriptuser\>"
syn match DnsmasqKeyword    "^\s*dhcp-sequential-ip\>"
syn match DnsmasqKeyword    "^\s*dhcp-subscrid\>"
syn match DnsmasqKeyword    "^\s*dhcp-userclass\>"
syn match DnsmasqKeyword    "^\s*dhcp-vendorclass\>"
syn match DnsmasqKeyword    "^\s*dns-rr\>"
syn match DnsmasqKeyword    "^\s*dnssec\>"
syn match DnsmasqKeyword    "^\s*dnssec-check-unsigned\>"
syn match DnsmasqKeyword    "^\s*dnssec-no-timecheck\>"
syn match DnsmasqKeyword    "^\s*dns-forward-max\>"
syn match DnsmasqKeyword    "^\s*domain\>"
syn match DnsmasqKeyword    "^\s*domain-needed\>"
syn match DnsmasqKeyword    "^\s*edns-packet-max\>"
syn match DnsmasqKeyword    "^\s*enable-dbus\>"
syn match DnsmasqKeyword    "^\s*enable-ra\>"
syn match DnsmasqKeyword    "^\s*enable-tftp\>"
syn match DnsmasqKeyword    "^\s*except-interface\>"
syn match DnsmasqKeyword    "^\s*expand-hosts\>"
syn match DnsmasqKeyword    "^\s*filterwin2k\>"
syn match DnsmasqKeyword    "^\s*group\>"
syn match DnsmasqKeyword    "^\s*host-record\>"
syn match DnsmasqKeyword    "^\s*interface\>"
syn match DnsmasqKeyword    "^\s*interface-name\>"
syn match DnsmasqKeyword    "^\s*ipset\>"
syn match DnsmasqKeyword    "^\s*keep-in-foreground\>"
syn match DnsmasqKeyword    "^\s*leasefile-ro\>"
syn match DnsmasqKeyword    "^\s*listen-address\>"
syn match DnsmasqKeyword    "^\s*local\>"
syn match DnsmasqKeyword    "^\s*localmx\>"
syn match DnsmasqKeyword    "^\s*local-ttl\>"
syn match DnsmasqKeyword    "^\s*local-service\>"
syn match DnsmasqKeyword    "^\s*localise-queries\>"
syn match DnsmasqKeyword    "^\s*log-async\>"
syn match DnsmasqKeyword    "^\s*log-dhcp\>"
syn match DnsmasqKeyword    "^\s*log-facility\>"
syn match DnsmasqKeyword    "^\s*log-queries\>"
syn match DnsmasqKeyword    "^\s*max-ttl\>"
syn match DnsmasqKeyword    "^\s*max-cache-ttl\>"
syn match DnsmasqKeyword    "^\s*min-port\>"
syn match DnsmasqKeyword    "^\s*mx-host\>"
syn match DnsmasqKeyword    "^\s*mx-target\>"
syn match DnsmasqKeyword    "^\s*naptr-record\>"
syn match DnsmasqKeyword    "^\s*neg-ttl\>"
syn match DnsmasqKeyword    "^\s*no-daemon\>"
syn match DnsmasqKeyword    "^\s*no-dhcp-interface\>"
syn match DnsmasqKeyword    "^\s*no-hosts\>"
syn match DnsmasqKeyword    "^\s*no-negcache\>"
syn match DnsmasqKeyword    "^\s*no-ping\>"
syn match DnsmasqKeyword    "^\s*no-poll\>"
syn match DnsmasqKeyword    "^\s*no-resolv\>"
syn match DnsmasqKeyword    "^\s*pid-file\>"
syn match DnsmasqKeyword    "^\s*port\>"
syn match DnsmasqKeyword    "^\s*proxy-dnssec\>"
syn match DnsmasqKeyword    "^\s*ptr-record\>"
syn match DnsmasqKeyword    "^\s*pxe-prompt\>"
syn match DnsmasqKeyword    "^\s*pxe-service\>"
syn match DnsmasqKeyword    "^\s*query-port\>"
syn match DnsmasqKeyword    "^\s*quiet-ra\>"
syn match DnsmasqKeyword    "^\s*quiet-dhcp\>"
syn match DnsmasqKeyword    "^\s*quiet-dhcp6\>"
syn match DnsmasqKeyword    "^\s*ra-param\>"
syn match DnsmasqKeyword    "^\s*read-ethers\>"
syn match DnsmasqKeyword    "^\s*rebind-domain-ok\>"
syn match DnsmasqKeyword    "^\s*rebind-localhost-ok\>"
syn match DnsmasqKeyword    "^\s*resolv-file\>"
syn match DnsmasqKeyword    "^\s*rev-server\>"
syn match DnsmasqKeyword    "^\s*selfmx\>"
syn match DnsmasqKeyword    "^\s*server\>"
syn match DnsmasqKeyword    "^\s*servers-file\>"
syn match DnsmasqKeyword    "^\s*srv-host\>"
syn match DnsmasqKeyword    "^\s*stop-dns-rebind\>"
syn match DnsmasqKeyword    "^\s*strict-order\>"
syn match DnsmasqKeyword    "^\s*synth-domain\>"
syn match DnsmasqKeyword    "^\s*tag-if\>"
syn match DnsmasqKeyword    "^\s*test\>"
syn match DnsmasqKeyword    "^\s*tftp-max\>"
syn match DnsmasqKeyword    "^\s*tftp-lowercase\>"
syn match DnsmasqKeyword    "^\s*tftp-no-blocksize\>"
syn match DnsmasqKeyword    "^\s*tftp-port-range\>"
syn match DnsmasqKeyword    "^\s*tftp-root\>"
syn match DnsmasqKeyword    "^\s*tftp-secure\>"
syn match DnsmasqKeyword    "^\s*tftp-unique-root\>"
syn match DnsmasqKeyword    "^\s*txt-record\>"
syn match DnsmasqKeyword    "^\s*user\>"
syn match DnsmasqKeyword    "^\s*version\>"


if b:dnsmasq_backrgound_light == 1
    hi def DnsmasqKeyword	ctermfg=DarkGreen guifg=DarkGreen
else
    hi def link DnsmasqKeyword  Keyword
endif
hi def link DnsmasqKeywordSpecial Type
hi def link DnsmasqTodo		Todo
hi def link DnsmasqSpecial	Constant
hi def link DnsmasqIPv4		Identifier
hi def link DnsmasqSubnet2	DnsmasqSubnet
hi def link DnsmasqSubnet	DnsmasqMac
hi def link DnsmasqRange	DnsmasqMac
hi def link DnsmasqMac		Preproc
hi def link DnsmasqTime		Preproc
hi def link DnsmasqComment	Comment
hi def link DnsmasqTrailSpace	DiffDelete
hi def link DnsmasqString	Constant
hi def link DnsmasqValues	Normal

let b:current_syntax = "dnsmasq"

let &cpo = s:cpo_save
unlet s:cpo_save

