" Vim syntax file
" Language: resolver configuration file
" Maintainer: Radu Dineiu <radu.dineiu@gmail.com>
" URL: https://raw.github.com/rid9/vim-resolv/master/resolv.vim
" Last Change: 2020 Mar 10
" Version: 1.4
"
" Credits:
"   David Necas (Yeti) <yeti@physics.muni.cz>
"   Stefano Zacchiroli <zack@debian.org>
"   DJ Lucas <dj@linuxfromscratch.org>
"
" Changelog:
"   - 1.4: Added IPv6 support for sortlist.
"   - 1.3: Added IPv6 support for IPv4 dot-decimal notation.
"   - 1.2: Added new options.
"   - 1.1: Added IPv6 support.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
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

" Nameserver IPv4
syn match resolvIPNameserver contained /\%(\%(\d\{1,4}\.\)\{3}\d\{1,4}\%(\s\|$\)\)\+/ contains=@resolvIPCluster

" Nameserver IPv6
syn match resolvIPNameserver contained /\<\%(\x\{1,4}:\)\{6}\%(\x\{1,4}:\x\{1,4}\)\>/
syn match resolvIPNameserver contained /\s\@<=::\%(\x\{1,4}:\)\{,6}\x\{1,4}\>/
syn match resolvIPNameserver contained /\s\@<=::\%(\x\{1,4}:\)\{,5}\%(\d\{1,4}\.\)\{3}\d\{1,4}\>/
syn match resolvIPNameserver contained /\<\%(\x\{1,4}:\)\{1}:\%(\x\{1,4}:\)\{,5}\x\{1,4}\>/
syn match resolvIPNameserver contained /\<\%(\x\{1,4}:\)\{1}:\%(\x\{1,4}:\)\{,4}\%(\d\{1,4}\.\)\{3}\d\{1,4}\>/
syn match resolvIPNameserver contained /\<\%(\x\{1,4}:\)\{2}:\%(\x\{1,4}:\)\{,4}\x\{1,4}\>/
syn match resolvIPNameserver contained /\<\%(\x\{1,4}:\)\{2}:\%(\x\{1,4}:\)\{,3}\%(\d\{1,4}\.\)\{3}\d\{1,4}\>/
syn match resolvIPNameserver contained /\<\%(\x\{1,4}:\)\{3}:\%(\x\{1,4}:\)\{,3}\x\{1,4}\>/
syn match resolvIPNameserver contained /\<\%(\x\{1,4}:\)\{3}:\%(\x\{1,4}:\)\{,2}\%(\d\{1,4}\.\)\{3}\d\{1,4}\>/
syn match resolvIPNameserver contained /\<\%(\x\{1,4}:\)\{4}:\%(\x\{1,4}:\)\{,2}\x\{1,4}\>/
syn match resolvIPNameserver contained /\<\%(\x\{1,4}:\)\{4}:\%(\x\{1,4}:\)\{,1}\%(\d\{1,4}\.\)\{3}\d\{1,4}\>/
syn match resolvIPNameserver contained /\<\%(\x\{1,4}:\)\{5}:\%(\d\{1,4}\.\)\{3}\d\{1,4}\>/
syn match resolvIPNameserver contained /\<\%(\x\{1,4}:\)\{6}:\x\{1,4}\>/
syn match resolvIPNameserver contained /\<\%(\x\{1,4}:\)\{1,7}:\%(\s\|;\|$\)\@=/

" Search hostname
syn match resolvHostnameSearch contained /\%(\%([-0-9A-Za-z_]\+\.\)*[-0-9A-Za-z_]\+\.\?\%(\s\|$\)\)\+/

" Sortlist IPv4
syn match resolvIPNetmaskSortList contained /\%(\%(\d\{1,4}\.\)\{3}\d\{1,4}\%(\/\%(\%(\d\{1,4}\.\)\{,3}\d\{1,4}\)\)\?\%(\s\|$\)\)\+/ contains=resolvOperator,@resolvIPCluster

" Sortlist IPv6
syn match resolvIPNetmaskSortList contained /\<\%(\x\{1,4}:\)\{6}\%(\x\{1,4}:\x\{1,4}\)\%(\/\d\{1,3}\)\?\>/
syn match resolvIPNetmaskSortList contained /\s\@<=::\%(\x\{1,4}:\)\{,6}\x\{1,4}\%(\/\d\{1,3}\)\?\>/
syn match resolvIPNetmaskSortList contained /\s\@<=::\%(\x\{1,4}:\)\{,5}\%(\d\{1,4}\.\)\{3}\d\{1,4}\%(\/\d\{1,3}\)\?\>/
syn match resolvIPNetmaskSortList contained /\<\%(\x\{1,4}:\)\{1}:\%(\x\{1,4}:\)\{,5}\x\{1,4}\%(\/\d\{1,3}\)\?\>/
syn match resolvIPNetmaskSortList contained /\<\%(\x\{1,4}:\)\{1}:\%(\x\{1,4}:\)\{,4}\%(\d\{1,4}\.\)\{3}\d\{1,4}\%(\/\d\{1,3}\)\?\>/
syn match resolvIPNetmaskSortList contained /\<\%(\x\{1,4}:\)\{2}:\%(\x\{1,4}:\)\{,4}\x\{1,4}\%(\/\d\{1,3}\)\?\>/
syn match resolvIPNetmaskSortList contained /\<\%(\x\{1,4}:\)\{2}:\%(\x\{1,4}:\)\{,3}\%(\d\{1,4}\.\)\{3}\d\{1,4}\%(\/\d\{1,3}\)\?\>/
syn match resolvIPNetmaskSortList contained /\<\%(\x\{1,4}:\)\{3}:\%(\x\{1,4}:\)\{,3}\x\{1,4}\%(\/\d\{1,3}\)\?\>/
syn match resolvIPNetmaskSortList contained /\<\%(\x\{1,4}:\)\{3}:\%(\x\{1,4}:\)\{,2}\%(\d\{1,4}\.\)\{3}\d\{1,4}\%(\/\d\{1,3}\)\?\>/
syn match resolvIPNetmaskSortList contained /\<\%(\x\{1,4}:\)\{4}:\%(\x\{1,4}:\)\{,2}\x\{1,4}\%(\/\d\{1,3}\)\?\>/
syn match resolvIPNetmaskSortList contained /\<\%(\x\{1,4}:\)\{4}:\%(\x\{1,4}:\)\{,1}\%(\d\{1,4}\.\)\{3}\d\{1,4}\%(\/\d\{1,3}\)\?\>/
syn match resolvIPNetmaskSortList contained /\<\%(\x\{1,4}:\)\{5}:\%(\d\{1,4}\.\)\{3}\d\{1,4}\%(\/\d\{1,3}\)\?\>/
syn match resolvIPNetmaskSortList contained /\<\%(\x\{1,4}:\)\{6}:\x\{1,4}\%(\/\d\{1,3}\)\?\>/
syn match resolvIPNetmaskSortList contained /\<\%(\x\{1,4}:\)\{1,7}:\%(\s\|;\|$\)\@=\%(\/\d\{1,3}\)\?/

" Identifiers
syn match resolvNameserver /^\s*nameserver\>/ nextgroup=resolvIPNameserver skipwhite
syn match resolvLwserver /^\s*lwserver\>/ nextgroup=resolvIPNameserver skipwhite
syn match resolvDomain /^\s*domain\>/ nextgroup=resolvHostname skipwhite
syn match resolvSearch /^\s*search\>/ nextgroup=resolvHostnameSearch skipwhite
syn match resolvSortList /^\s*sortlist\>/ nextgroup=resolvIPNetmaskSortList skipwhite
syn match resolvOptions /^\s*options\>/ nextgroup=resolvOption skipwhite

" Options
syn match resolvOption /\<\%(debug\|no_tld_query\|no-tld-query\|rotate\|no-check-names\|inet6\|ip6-bytestring\|\%(no-\)\?ip6-dotint\|edns0\|single-request\%(-reopen\)\?\|use-vc\)\>/ contained nextgroup=resolvOption skipwhite
syn match resolvOption /\<\%(ndots\|timeout\|attempts\):\d\+\>/ contained contains=resolvOperator nextgroup=resolvOption skipwhite

" Additional errors
syn match resolvError /^search .\{257,}/

hi def link resolvIP Number
hi def link resolvIPNetmask Number
hi def link resolvHostname String
hi def link resolvOption String

hi def link resolvIPNameserver Number
hi def link resolvHostnameSearch String
hi def link resolvIPNetmaskSortList Number

hi def link resolvNameServer Identifier
hi def link resolvLwserver Identifier
hi def link resolvDomain Identifier
hi def link resolvSearch Identifier
hi def link resolvSortList Identifier
hi def link resolvOptions Identifier

hi def link resolvComment Comment
hi def link resolvOperator Operator
hi def link resolvError Error
hi def link resolvIPError Error
hi def link resolvIPSpecial Special

let b:current_syntax = "resolv"

" vim: ts=8 ft=vim
