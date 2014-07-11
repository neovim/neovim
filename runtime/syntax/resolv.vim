" Vim syntax file
" Language: resolver configuration file
" Maintainer: Radu Dineiu <radu.dineiu@gmail.com>
" URL: https://raw.github.com/rid9/vim-resolv/master/resolv.vim
" Last Change: 2013 May 21
" Version: 1.0
"
" Credits:
"   David Necas (Yeti) <yeti@physics.muni.cz>
"   Stefano Zacchiroli <zack@debian.org>

if version < 600
	syntax clear
elseif exists("b:current_syntax")
	finish
endif

" Errors, comments and operators
syn match resolvError /./
syn match resolvComment /\s*[#;].*$/
syn match resolvOperator /[\/:]/ contained

" IP
syn cluster resolvIPCluster contains=resolvIPError,resolvIPSpecial
syn match resolvIPError /\%(\d\{4,}\|25[6-9]\|2[6-9]\d\|[3-9]\d\{2}\)[\.0-9]*/ contained
syn match resolvIPSpecial /\%(127\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}\)/ contained

" General
syn match resolvIP contained /\%(\d\{1,4}\.\)\{3}\d\{1,4}/ contains=@resolvIPCluster
syn match resolvIPNetmask contained /\%(\d\{1,4}\.\)\{3}\d\{1,4}\%(\/\%(\%(\d\{1,4}\.\)\{,3}\d\{1,4}\)\)\?/ contains=resolvOperator,@resolvIPCluster
syn match resolvHostname contained /\w\{-}\.[-0-9A-Za-z_\.]*/

" Particular
syn match resolvIPNameserver contained /\%(\%(\d\{1,4}\.\)\{3}\d\{1,4}\%(\s\|$\)\)\+/ contains=@resolvIPCluster
syn match resolvHostnameSearch contained /\%(\%([-0-9A-Za-z_]\+\.\)*[-0-9A-Za-z_]\+\.\?\%(\s\|$\)\)\+/
syn match resolvIPNetmaskSortList contained /\%(\%(\d\{1,4}\.\)\{3}\d\{1,4}\%(\/\%(\%(\d\{1,4}\.\)\{,3}\d\{1,4}\)\)\?\%(\s\|$\)\)\+/ contains=resolvOperator,@resolvIPCluster

" Identifiers
syn match resolvNameserver /^\s*nameserver\>/ nextgroup=resolvIPNameserver skipwhite
syn match resolvLwserver /^\s*lwserver\>/ nextgroup=resolvIPNameserver skipwhite
syn match resolvDomain /^\s*domain\>/ nextgroup=resolvHostname skipwhite
syn match resolvSearch /^\s*search\>/ nextgroup=resolvHostnameSearch skipwhite
syn match resolvSortList /^\s*sortlist\>/ nextgroup=resolvIPNetmaskSortList skipwhite
syn match resolvOptions /^\s*options\>/ nextgroup=resolvOption skipwhite

" Options
syn match resolvOption /\<\%(debug\|no_tld_query\|rotate\|no-check-names\|inet6\)\>/ contained nextgroup=resolvOption skipwhite
syn match resolvOption /\<\%(ndots\|timeout\|attempts\):\d\+\>/ contained contains=resolvOperator nextgroup=resolvOption skipwhite

" Additional errors
syn match resolvError /^search .\{257,}/

if version >= 508 || !exists("did_config_syntax_inits")
	if version < 508
		let did_config_syntax_inits = 1
		command! -nargs=+ HiLink hi link <args>
	else
		command! -nargs=+ HiLink hi def link <args>
	endif

	HiLink resolvIP Number
	HiLink resolvIPNetmask Number
	HiLink resolvHostname String
	HiLink resolvOption String

	HiLink resolvIPNameserver Number
	HiLink resolvHostnameSearch String
	HiLink resolvIPNetmaskSortList Number

	HiLink resolvNameServer Identifier
	HiLink resolvLwserver Identifier
	HiLink resolvDomain Identifier
	HiLink resolvSearch Identifier
	HiLink resolvSortList Identifier
	HiLink resolvOptions Identifier

	HiLink resolvComment Comment
	HiLink resolvOperator Operator
	HiLink resolvError Error
	HiLink resolvIPError Error
	HiLink resolvIPSpecial Special

	delcommand HiLink
endif

let b:current_syntax = "resolv"

" vim: ts=8 ft=vim
