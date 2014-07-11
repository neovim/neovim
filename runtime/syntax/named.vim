" Vim syntax file
" Language:	BIND configuration file
" Maintainer:	Nick Hibma <nick@van-laarhoven.org>
" Last change:	2007-01-30
" Filenames:	named.conf, rndc.conf
" Location:	http://www.van-laarhoven.org/vim/syntax/named.vim
"
" Previously maintained by glory hump <rnd@web-drive.ru> and updated by Marcin
" Dalecki.
"
" This file could do with a lot of improvements, so comments are welcome.
" Please submit the named.conf (segment) with any comments.
"
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case match

if version >= 600
  setlocal iskeyword=.,-,48-58,A-Z,a-z,_
else
  set iskeyword=.,-,48-58,A-Z,a-z,_
endif

if version >= 600
  syn sync match namedSync grouphere NONE "^(zone|controls|acl|key)"
endif

let s:save_cpo = &cpo
set cpo-=C

" BIND configuration file

syn match	namedComment	"//.*"
syn match	namedComment	"#.*"
syn region	namedComment	start="/\*" end="\*/"
syn region	namedString	start=/"/ end=/"/ contained
" --- omitted trailing semicolon
syn match	namedError	/[^;{#]$/

" --- top-level keywords

syn keyword	namedInclude	include nextgroup=namedString skipwhite
syn keyword	namedKeyword	acl key nextgroup=namedIntIdent skipwhite
syn keyword	namedKeyword	server nextgroup=namedIdentifier skipwhite
syn keyword	namedKeyword	controls nextgroup=namedSection skipwhite
syn keyword	namedKeyword	trusted-keys nextgroup=namedIntSection skipwhite
syn keyword	namedKeyword	logging nextgroup=namedLogSection skipwhite
syn keyword	namedKeyword	options nextgroup=namedOptSection skipwhite
syn keyword	namedKeyword	zone nextgroup=namedZoneString skipwhite

" --- Identifier: name of following { ... } Section
syn match	namedIdentifier	contained /\k\+/ nextgroup=namedSection skipwhite
" --- IntIdent: name of following IntSection
syn match	namedIntIdent	contained /"\=\k\+"\=/ nextgroup=namedIntSection skipwhite

" --- Section: { ... } clause
syn region	namedSection	contained start=+{+ end=+};+ contains=namedSection,namedIntKeyword

" --- IntSection: section that does not contain other sections
syn region	namedIntSection	contained start=+{+ end=+}+ contains=namedIntKeyword,namedError

" --- IntKeyword: keywords contained within `{ ... }' sections only
" + these keywords are contained within `key' and `acl' sections
syn keyword	namedIntKeyword	contained key algorithm
syn keyword	namedIntKeyword	contained secret nextgroup=namedString skipwhite

" + these keywords are contained within `server' section only
syn keyword	namedIntKeyword	contained bogus support-ixfr nextgroup=namedBool,namedNotBool skipwhite
syn keyword	namedIntKeyword	contained transfers nextgroup=namedNumber,namedNotNumber skipwhite
syn keyword	namedIntKeyword	contained transfer-format
syn keyword	namedIntKeyword	contained keys nextgroup=namedIntSection skipwhite

" + these keywords are contained within `controls' section only
syn keyword	namedIntKeyword	contained inet nextgroup=namedIPaddr,namedIPerror skipwhite
syn keyword	namedIntKeyword	contained unix nextgroup=namedString skipwhite
syn keyword	namedIntKeyword	contained port perm owner group nextgroup=namedNumber,namedNotNumber skipwhite
syn keyword	namedIntKeyword	contained allow nextgroup=namedIntSection skipwhite

" + these keywords are contained within `update-policy' section only
syn keyword	namedIntKeyword	contained grant nextgroup=namedString skipwhite
syn keyword	namedIntKeyword	contained name self subdomain wildcard nextgroup=namedString skipwhite
syn keyword	namedIntKeyword	TXT A PTR NS SOA A6 CNAME MX ANY skipwhite

" --- options
syn region	namedOptSection	contained start=+{+ end=+};+ contains=namedOption,namedCNOption,namedComment,namedParenError

syn keyword	namedOption	contained version directory
\		nextgroup=namedString skipwhite
syn keyword	namedOption	contained named-xfer dump-file pid-file
\		nextgroup=namedString skipwhite
syn keyword	namedOption	contained mem-statistics-file statistics-file
\		nextgroup=namedString skipwhite
syn keyword	namedOption	contained auth-nxdomain deallocate-on-exit
\		nextgroup=namedBool,namedNotBool skipwhite
syn keyword	namedOption	contained dialup fake-iquery fetch-glue
\		nextgroup=namedBool,namedNotBool skipwhite
syn keyword	namedOption	contained has-old-clients host-statistics
\		nextgroup=namedBool,namedNotBool skipwhite
syn keyword	namedOption	contained maintain-ixfr-base multiple-cnames
\		nextgroup=namedBool,namedNotBool skipwhite
syn keyword	namedOption	contained notify recursion rfc2308-type1
\		nextgroup=namedBool,namedNotBool skipwhite
syn keyword	namedOption	contained use-id-pool treat-cr-as-space
\		nextgroup=namedBool,namedNotBool skipwhite
syn keyword	namedOption	contained also-notify forwarders
\		nextgroup=namedIPlist skipwhite
syn keyword	namedOption	contained forward check-names
syn keyword	namedOption	contained allow-query allow-transfer allow-recursion
\		nextgroup=namedAML skipwhite
syn keyword	namedOption	contained blackhole listen-on
\		nextgroup=namedIntSection skipwhite
syn keyword	namedOption	contained lame-ttl max-transfer-time-in
\		nextgroup=namedNumber,namedNotNumber skipwhite
syn keyword	namedOption	contained max-ncache-ttl min-roots
\		nextgroup=namedNumber,namedNotNumber skipwhite
syn keyword	namedOption	contained serial-queries transfers-in
\		nextgroup=namedNumber,namedNotNumber skipwhite
syn keyword	namedOption	contained transfers-out transfers-per-ns
syn keyword	namedOption	contained transfer-format
syn keyword	namedOption	contained transfer-source
\		nextgroup=namedIPaddr,namedIPerror skipwhite
syn keyword	namedOption	contained max-ixfr-log-size
\		nextgroup=namedNumber,namedNotNumber skipwhite
syn keyword	namedOption	contained coresize datasize files stacksize
syn keyword	namedOption	contained cleaning-interval interface-interval statistics-interval heartbeat-interval
\		nextgroup=namedNumber,namedNotNumber skipwhite
syn keyword	namedOption	contained topology sortlist rrset-order
\		nextgroup=namedIntSection skipwhite

syn match	namedOption	contained /\<query-source\s\+.*;/he=s+12 contains=namedQSKeywords
syn keyword	namedQSKeywords	contained address port
syn match	namedCNOption	contained /\<check-names\s\+.*;/he=s+11 contains=namedCNKeywords
syn keyword	namedCNKeywords	contained fail warn ignore master slave response

" --- logging facilities
syn region	namedLogSection	contained start=+{+ end=+};+ contains=namedLogOption
syn keyword	namedLogOption	contained channel nextgroup=namedIntIdent skipwhite
syn keyword	namedLogOption	contained category nextgroup=namedIntIdent skipwhite
syn keyword	namedIntKeyword	contained syslog null versions size severity
syn keyword	namedIntKeyword	contained file nextgroup=namedString skipwhite
syn keyword	namedIntKeyword	contained print-category print-severity print-time nextgroup=namedBool,namedNotBool skipwhite

" --- zone section
syn region	namedZoneString	contained oneline start=+"+ end=+"+ skipwhite
\		contains=namedDomain,namedIllegalDom
\		nextgroup=namedZoneClass,namedZoneSection
syn keyword	namedZoneClass	contained in hs hesiod chaos
\		IN HS HESIOD CHAOS
\		nextgroup=namedZoneSection skipwhite

syn region	namedZoneSection	contained start=+{+ end=+};+ contains=namedZoneOpt,namedCNOption,namedComment,namedMasters,namedParenError
syn keyword	namedZoneOpt	contained file ixfr-base
\		nextgroup=namedString skipwhite
syn keyword	namedZoneOpt	contained notify dialup
\		nextgroup=namedBool,namedNotBool skipwhite
syn keyword	namedZoneOpt	contained pubkey forward
syn keyword	namedZoneOpt	contained max-transfer-time-in
\		nextgroup=namedNumber,namedNotNumber skipwhite
syn keyword	namedZoneOpt	contained type nextgroup=namedZoneType skipwhite
syn keyword	namedZoneType	contained master slave stub forward hint

syn keyword	namedZoneOpt	contained masters forwarders
\		nextgroup=namedIPlist skipwhite
syn region	namedIPlist	contained start=+{+ end=+};+ contains=namedIPaddr,namedIPerror,namedParenError,namedComment
syn keyword	namedZoneOpt	contained allow-update allow-query allow-transfer
\		nextgroup=namedAML skipwhite
syn keyword	namedZoneOpt	contained update-policy
\		nextgroup=namedIntSection skipwhite

" --- boolean parameter
syn match	namedNotBool	contained "[^ 	;]\+"
syn keyword	namedBool	contained yes no true false 1 0

" --- number parameter
syn match	namedNotNumber	contained "[^ 	0-9;]\+"
syn match	namedNumber	contained "\d\+"

" --- address match list
syn region	namedAML	contained start=+{+ end=+};+ contains=namedParenError,namedComment,namedString

" --- IPs & Domains
syn match	namedIPaddr	contained /\<[0-9]\{1,3}\(\.[0-9]\{1,3}\)\{3};/he=e-1
syn match	namedDomain	contained /\<[0-9A-Za-z][-0-9A-Za-z.]\+\>/ nextgroup=namedSpareDot
syn match	namedDomain	contained /"\."/ms=s+1,me=e-1
syn match	namedSpareDot	contained /\./

" --- syntax errors
syn match	namedIllegalDom	contained /"\S*[^-A-Za-z0-9.[:space:]]\S*"/ms=s+1,me=e-1
syn match	namedIPerror	contained /\<\S*[^0-9.[:space:];]\S*/
syn match	namedEParenError	contained +{+
syn match	namedParenError	+}\([^;]\|$\)+

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_named_syn_inits")
  if version < 508
    let did_named_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink namedComment	Comment
  HiLink namedInclude	Include
  HiLink namedKeyword	Keyword
  HiLink namedIntKeyword	Keyword
  HiLink namedIdentifier	Identifier
  HiLink namedIntIdent	Identifier

  HiLink namedString	String
  HiLink namedBool	Type
  HiLink namedNotBool	Error
  HiLink namedNumber	Number
  HiLink namedNotNumber	Error

  HiLink namedOption	namedKeyword
  HiLink namedLogOption	namedKeyword
  HiLink namedCNOption	namedKeyword
  HiLink namedQSKeywords	Type
  HiLink namedCNKeywords	Type
  HiLink namedLogCategory	Type
  HiLink namedIPaddr	Number
  HiLink namedDomain	Identifier
  HiLink namedZoneOpt	namedKeyword
  HiLink namedZoneType	Type
  HiLink namedParenError	Error
  HiLink namedEParenError	Error
  HiLink namedIllegalDom	Error
  HiLink namedIPerror	Error
  HiLink namedSpareDot	Error
  HiLink namedError	Error

  delcommand HiLink
endif

let &cpo = s:save_cpo
unlet s:save_cpo

let b:current_syntax = "named"

" vim: ts=17
