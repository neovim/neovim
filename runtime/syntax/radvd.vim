" Vim syntax file
" Language:	radvd configuration
" Maintainer:	mdspan <mdspan.github@gmail.com>
" Last Change:	2026 Aug 26
" Reference:	radvd.conf(5)

if exists("b:current_syntax")
  finish
endif

" block keywords
syn keyword radvdBlock		interface prefix route clients abro
syn keyword radvdBlock		RDNSS DNSSL AdvRASrcAddress nat64prefix

" interface options
syn keyword radvdOption		IgnoreIfMissing AdvSendAdvert UnicastOnly
syn keyword radvdOption		AdvRASolicitedUnicast MaxRtrAdvInterval
syn keyword radvdOption		MinRtrAdvInterval MinDelayBetweenRAs
syn keyword radvdOption		AdvManagedFlag AdvOtherConfigFlag AdvLinkMTU
syn keyword radvdOption		AdvReachableTime AdvRetransTimer AdvCurHopLimit
syn keyword radvdOption		AdvDefaultLifetime AdvDefaultPreference
syn keyword radvdOption		AdvSourceLLAddress AdvHomeAgentFlag
syn keyword radvdOption		AdvHomeAgentInfo HomeAgentLifetime
syn keyword radvdOption		HomeAgentPreference AdvMobRtrSupportFlag
syn keyword radvdOption		AdvIntervalOpt AdvCaptivePortalAPI

" prefix options
syn keyword radvdOption		AdvOnLink AdvAutonomous AdvRouterAddr
syn keyword radvdOption		AdvValidLifetime AdvPreferredLifetime
syn keyword radvdOption		DeprecatePrefix DecrementLifetimes
syn keyword radvdOption		Base6Interface Base6to4Interface

" route, RDNSS, DNSSL and abro options
syn keyword radvdOption		AdvRouteLifetime AdvRoutePreference RemoveRoute
syn keyword radvdOption		AdvRDNSSLifetime FlushRDNSS
syn keyword radvdOption		AdvDNSSLLifetime FlushDNSSL
syn keyword radvdOption		AdvVersionLow AdvVersionHigh AdvValidLifeTime

" values
syn keyword radvdBool		on off
syn keyword radvdPreference	low medium high
syn keyword radvdInfinity	infinity
syn match   radvdNumber		"\<\d\+\%(\.\d\+\)\=\>"
syn match   radvdIPv6		"\%(\x\{1,4}\)\=\%(:\x\{0,4}\)\+\%(/\d\{1,3}\)\="

" delimiters
syn match   radvdDelimiter	"[{};]"

" comments
syn keyword radvdTodo		contained TODO FIXME XXX NOTE
syn match   radvdComment	"#.*$" contains=radvdTodo,@Spell
syn match   radvdComment	"//.*$" contains=radvdTodo,@Spell
syn region  radvdComment	start="/\*" end="\*/" contains=radvdTodo,@Spell

hi def link radvdBlock		Keyword
hi def link radvdOption		Identifier
hi def link radvdBool		Boolean
hi def link radvdPreference	Constant
hi def link radvdInfinity	Constant
hi def link radvdNumber		Number
hi def link radvdIPv6		Constant
hi def link radvdDelimiter	Delimiter
hi def link radvdTodo		Todo
hi def link radvdComment	Comment

let b:current_syntax = "radvd"
