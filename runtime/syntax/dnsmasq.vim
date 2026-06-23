" Vim syntax file
" Maintainer:	Thilo Six
" Contact:	vim-foo@xk2c-foo.de
"		:3s+-foo++g
" Description:	highlight dnsmasq configuration files
" File:		runtime/syntax/dnsmasq.vim
" Version:	2.76
" Last Change:	2015 Sep 27
" 2026 Jun 23 by Vim project update dnsmasq keywords #20616
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

" quit when a syntax file was already loaded
if exists("b:current_syntax") || &compatible
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

syn match DnsmasqKeyword    "^\s*\zsadd-cpe-id\>"
syn match DnsmasqKeyword    "^\s*\zsadd-mac\>"
syn match DnsmasqKeyword    "^\s*\zsadd-subnet\>"
syn match DnsmasqKeyword    "^\s*\zsaddn-hosts\>"
syn match DnsmasqKeyword    "^\s*\zsaddress\>"
syn match DnsmasqKeyword    "^\s*\zsalias\>"
syn match DnsmasqKeyword    "^\s*\zsall-servers\>"
syn match DnsmasqKeyword    "^\s*\zsauth-peer\>"
syn match DnsmasqKeyword    "^\s*\zsauth-sec-servers\>"
syn match DnsmasqKeyword    "^\s*\zsauth-server\>"
syn match DnsmasqKeyword    "^\s*\zsauth-soa\>"
syn match DnsmasqKeyword    "^\s*\zsauth-ttl\>"
syn match DnsmasqKeyword    "^\s*\zsauth-zone\>"
syn match DnsmasqKeyword    "^\s*\zsbind-dynamic\>"
syn match DnsmasqKeyword    "^\s*\zsbind-interfaces\>"
syn match DnsmasqKeyword    "^\s*\zsbogus-nxdomain\>"
syn match DnsmasqKeyword    "^\s*\zsbogus-priv\>"
syn match DnsmasqKeyword    "^\s*\zsbootp-dynamic\>"
syn match DnsmasqKeyword    "^\s*\zsbridge-interface\>"
syn match DnsmasqKeyword    "^\s*\zscaa-record\>"
syn match DnsmasqKeyword    "^\s*\zscache-rr\>"
syn match DnsmasqKeyword    "^\s*\zscache-size\>"
syn match DnsmasqKeyword    "^\s*\zsclear-on-reload\>"
syn match DnsmasqKeyword    "^\s*\zscname\>"
syn match DnsmasqKeyword    "^\s*\zsconf-dir\>"
syn match DnsmasqKeyword    "^\s*\zsconf-file\>"
syn match DnsmasqKeyword    "^\s*\zsconf-script\>"
syn match DnsmasqKeyword    "^\s*\zsconnmark-allowlist-enable\>"
syn match DnsmasqKeyword    "^\s*\zsconnmark-allowlist\>"
syn match DnsmasqKeyword    "^\s*\zsconntrack\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-alternate-port\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-authoritative\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-boot\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-broadcast\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-circuitid\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-client-update\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-duid\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-fqdn\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-generate-names\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-host\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-hostsdir\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-hostsfile\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-ignore-clid\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-ignore-names\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-ignore\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-lease-max\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-leasefile\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-luascript\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-mac\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-match\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-name-match\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-no-override\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-option-force\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-option-pxe\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-option\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-optsdir\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-optsfile\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-proxy\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-pxe-vendor\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-range\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-rapid-commit\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-relay\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-remoteid\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-reply-delay\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-script\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-scriptuser\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-sequential-ip\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-split-relay\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-subscrid\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-ttl\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-userclass\>"
syn match DnsmasqKeyword    "^\s*\zsdhcp-vendorclass\>"
syn match DnsmasqKeyword    "^\s*\zsdns-forward-max\>"
syn match DnsmasqKeyword    "^\s*\zsdns-loop-detect\>"
syn match DnsmasqKeyword    "^\s*\zsdns-rr\>"
syn match DnsmasqKeyword    "^\s*\zsdnssec-check-unsigned\>"
syn match DnsmasqKeyword    "^\s*\zsdnssec-debug\>"
syn match DnsmasqKeyword    "^\s*\zsdnssec-limits\>"
syn match DnsmasqKeyword    "^\s*\zsdnssec-no-timecheck\>"
syn match DnsmasqKeyword    "^\s*\zsdnssec-timestamp\>"
syn match DnsmasqKeyword    "^\s*\zsdnssec\>"
syn match DnsmasqKeyword    "^\s*\zsdo-0x20-encode\>"
syn match DnsmasqKeyword    "^\s*\zsdo-x20-encode\>"
syn match DnsmasqKeyword    "^\s*\zsdomain-needed\>"
syn match DnsmasqKeyword    "^\s*\zsdomain\>"
syn match DnsmasqKeyword    "^\s*\zsdumpfile\>"
syn match DnsmasqKeyword    "^\s*\zsdumpmask\>"
syn match DnsmasqKeyword    "^\s*\zsdynamic-host\>"
syn match DnsmasqKeyword    "^\s*\zsedns-packet-max\>"
syn match DnsmasqKeyword    "^\s*\zsenable-dbus\>"
syn match DnsmasqKeyword    "^\s*\zsenable-ra\>"
syn match DnsmasqKeyword    "^\s*\zsenable-tftp\>"
syn match DnsmasqKeyword    "^\s*\zsenable-ubus\>"
syn match DnsmasqKeyword    "^\s*\zsexcept-interface\>"
syn match DnsmasqKeyword    "^\s*\zsexpand-hosts\>"
syn match DnsmasqKeyword    "^\s*\zsfast-dns-retry\>"
syn match DnsmasqKeyword    "^\s*\zsfilter-AAAA\>"
syn match DnsmasqKeyword    "^\s*\zsfilter-A\>"
syn match DnsmasqKeyword    "^\s*\zsfilter-rr\>"
syn match DnsmasqKeyword    "^\s*\zsfilterwin2k\>"
syn match DnsmasqKeyword    "^\s*\zsgroup\>"
syn match DnsmasqKeyword    "^\s*\zshelp\>"
syn match DnsmasqKeyword    "^\s*\zshost-record\>"
syn match DnsmasqKeyword    "^\s*\zshostsdir\>"
syn match DnsmasqKeyword    "^\s*\zsignore-address\>"
syn match DnsmasqKeyword    "^\s*\zsinterface-name\>"
syn match DnsmasqKeyword    "^\s*\zsinterface\>"
syn match DnsmasqKeyword    "^\s*\zsipset\>"
syn match DnsmasqKeyword    "^\s*\zskeep-in-foreground\>"
syn match DnsmasqKeyword    "^\s*\zsleasefile-ro\>"
syn match DnsmasqKeyword    "^\s*\zsleasequery\>"
syn match DnsmasqKeyword    "^\s*\zslisten-address\>"
syn match DnsmasqKeyword    "^\s*\zslocal-service\>"
syn match DnsmasqKeyword    "^\s*\zslocal-ttl\>"
syn match DnsmasqKeyword    "^\s*\zslocal\>"
syn match DnsmasqKeyword    "^\s*\zslocalise-queries\>"
syn match DnsmasqKeyword    "^\s*\zslocalmx\>"
syn match DnsmasqKeyword    "^\s*\zslog-async\>"
syn match DnsmasqKeyword    "^\s*\zslog-debug\>"
syn match DnsmasqKeyword    "^\s*\zslog-dhcp\>"
syn match DnsmasqKeyword    "^\s*\zslog-facility\>"
syn match DnsmasqKeyword    "^\s*\zslog-malloc\>"
syn match DnsmasqKeyword    "^\s*\zslog-queries\>"
syn match DnsmasqKeyword    "^\s*\zsmax-cache-ttl\>"
syn match DnsmasqKeyword    "^\s*\zsmax-port\>"
syn match DnsmasqKeyword    "^\s*\zsmax-tcp-connections\>"
syn match DnsmasqKeyword    "^\s*\zsmax-ttl\>"
syn match DnsmasqKeyword    "^\s*\zsmin-cache-ttl\>"
syn match DnsmasqKeyword    "^\s*\zsmin-port\>"
syn match DnsmasqKeyword    "^\s*\zsmx-host\>"
syn match DnsmasqKeyword    "^\s*\zsmx-target\>"
syn match DnsmasqKeyword    "^\s*\zsnaptr-record\>"
syn match DnsmasqKeyword    "^\s*\zsneg-ttl\>"
syn match DnsmasqKeyword    "^\s*\zsnftset\>"
syn match DnsmasqKeyword    "^\s*\zsno-0x20-encode\>"
syn match DnsmasqKeyword    "^\s*\zsno-daemon\>"
syn match DnsmasqKeyword    "^\s*\zsno-dhcp-interface\>"
syn match DnsmasqKeyword    "^\s*\zsno-dhcpv4-interface\>"
syn match DnsmasqKeyword    "^\s*\zsno-dhcpv6-interface\>"
syn match DnsmasqKeyword    "^\s*\zsno-hosts\>"
syn match DnsmasqKeyword    "^\s*\zsno-ident\>"
syn match DnsmasqKeyword    "^\s*\zsno-negcache\>"
syn match DnsmasqKeyword    "^\s*\zsno-ping\>"
syn match DnsmasqKeyword    "^\s*\zsno-poll\>"
syn match DnsmasqKeyword    "^\s*\zsno-resolv\>"
syn match DnsmasqKeyword    "^\s*\zsno-round-robin\>"
syn match DnsmasqKeyword    "^\s*\zspid-file\>"
syn match DnsmasqKeyword    "^\s*\zsport-limit\>"
syn match DnsmasqKeyword    "^\s*\zsport\>"
syn match DnsmasqKeyword    "^\s*\zsproxy-dnssec\>"
syn match DnsmasqKeyword    "^\s*\zsptr-record\>"
syn match DnsmasqKeyword    "^\s*\zspxe-prompt\>"
syn match DnsmasqKeyword    "^\s*\zspxe-service\>"
syn match DnsmasqKeyword    "^\s*\zsquery-port\>"
syn match DnsmasqKeyword    "^\s*\zsquiet-dhcp6\>"
syn match DnsmasqKeyword    "^\s*\zsquiet-dhcp\>"
syn match DnsmasqKeyword    "^\s*\zsquiet-ra\>"
syn match DnsmasqKeyword    "^\s*\zsquiet-tftp\>"
syn match DnsmasqKeyword    "^\s*\zsra-param\>"
syn match DnsmasqKeyword    "^\s*\zsread-ethers\>"
syn match DnsmasqKeyword    "^\s*\zsrebind-domain-ok\>"
syn match DnsmasqKeyword    "^\s*\zsrebind-localhost-ok\>"
syn match DnsmasqKeyword    "^\s*\zsresolv-file\>"
syn match DnsmasqKeyword    "^\s*\zsrev-server\>"
syn match DnsmasqKeyword    "^\s*\zsscript-arp\>"
syn match DnsmasqKeyword    "^\s*\zsscript-on-renewal\>"
syn match DnsmasqKeyword    "^\s*\zsselfmx\>"
syn match DnsmasqKeyword    "^\s*\zsserver\>"
syn match DnsmasqKeyword    "^\s*\zsservers-file\>"
syn match DnsmasqKeyword    "^\s*\zsshared-network\>"
syn match DnsmasqKeyword    "^\s*\zssrv-host\>"
syn match DnsmasqKeyword    "^\s*\zsstop-dns-rebind\>"
syn match DnsmasqKeyword    "^\s*\zsstrict-order\>"
syn match DnsmasqKeyword    "^\s*\zsstrip-mac\>"
syn match DnsmasqKeyword    "^\s*\zsstrip-subnet\>"
syn match DnsmasqKeyword    "^\s*\zssynth-domain\>"
syn match DnsmasqKeyword    "^\s*\zstag-if\>"
syn match DnsmasqKeyword    "^\s*\zstest\>"
syn match DnsmasqKeyword    "^\s*\zstftp-lowercase\>"
syn match DnsmasqKeyword    "^\s*\zstftp-max\>"
syn match DnsmasqKeyword    "^\s*\zstftp-mtu\>"
syn match DnsmasqKeyword    "^\s*\zstftp-no-blocksize\>"
syn match DnsmasqKeyword    "^\s*\zstftp-no-fail\>"
syn match DnsmasqKeyword    "^\s*\zstftp-port-range\>"
syn match DnsmasqKeyword    "^\s*\zstftp-root\>"
syn match DnsmasqKeyword    "^\s*\zstftp-secure\>"
syn match DnsmasqKeyword    "^\s*\zstftp-single-port\>"
syn match DnsmasqKeyword    "^\s*\zstftp-unique-root\>"
syn match DnsmasqKeyword    "^\s*\zstrust-anchor\>"
syn match DnsmasqKeyword    "^\s*\zstxt-record\>"
syn match DnsmasqKeyword    "^\s*\zsumbrella\>"
syn match DnsmasqKeyword    "^\s*\zsuse-stale-cache\>"
syn match DnsmasqKeyword    "^\s*\zsuser\>"
syn match DnsmasqKeyword    "^\s*\zsversion\>"


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

