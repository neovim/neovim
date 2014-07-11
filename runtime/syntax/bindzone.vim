" Vim syntax file
" Language:     BIND zone files (RFC 1035)
" Maintainer:   Julian Mehnle <julian@mehnle.net>
" URL:          http://www.mehnle.net/source/odds+ends/vim/syntax/
" Last Change:  Thu 2011-07-16 20:42:00 UTC
" 
" Based on an earlier version by Вячеслав Горбанев (Slava Gorbanev), with
" heavy modifications.
" 
" $Id: bindzone.vim 12 2011-07-16 21:09:57Z julian $

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case match

" Directives
syn region      zoneRRecord     start=/^/ end=/$/ contains=zoneOwnerName,zoneSpecial,zoneTTL,zoneClass,zoneRRType,zoneComment,zoneUnknown

syn match       zoneDirective   /^\$ORIGIN\s\+/   nextgroup=zoneOrigin,zoneUnknown
syn match       zoneDirective   /^\$TTL\s\+/      nextgroup=zoneTTL,zoneUnknown
syn match       zoneDirective   /^\$INCLUDE\s\+/  nextgroup=zoneText,zoneUnknown
syn match       zoneDirective   /^\$GENERATE\s/

syn match       zoneUnknown     contained /\S\+/

syn match       zoneOwnerName   contained /^[^[:space:]!"#$%&'()*+,\/:;<=>?@[\]\^`{|}~]\+\(\s\|;\)\@=/ nextgroup=zoneTTL,zoneClass,zoneRRType skipwhite
syn match       zoneOrigin      contained  /[^[:space:]!"#$%&'()*+,\/:;<=>?@[\]\^`{|}~]\+\(\s\|;\|$\)\@=/
syn match       zoneDomain      contained  /[^[:space:]!"#$%&'()*+,\/:;<=>?@[\]\^`{|}~]\+\(\s\|;\|$\)\@=/

syn match       zoneSpecial     contained /^[@*.]\s/
syn match       zoneTTL         contained /\s\@<=\d[0-9WwDdHhMmSs]*\(\s\|$\)\@=/ nextgroup=zoneClass,zoneRRType skipwhite
syn keyword     zoneClass       contained IN CHAOS nextgroup=zoneRRType,zoneTTL skipwhite
syn keyword     zoneRRType      contained A AAAA CNAME DNAME HINFO MX NS PTR SOA SRV TXT SPF nextgroup=zoneRData skipwhite
syn match       zoneRData       contained /[^;]*/ contains=zoneDomain,zoneIPAddr,zoneIP6Addr,zoneText,zoneNumber,zoneParen,zoneUnknown

syn match       zoneIPAddr      contained /\<[0-9]\{1,3}\(\.[0-9]\{1,3}\)\{,3}\>/

"   Plain IPv6 address          IPv6-embedded-IPv4 address
"   1111:2:3:4:5:6:7:8          1111:2:3:4:5:6:127.0.0.1
syn match       zoneIP6Addr     contained /\<\(\x\{1,4}:\)\{6}\(\x\{1,4}:\x\{1,4}\|\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\>/
"   ::[...:]8                   ::[...:]127.0.0.1
syn match       zoneIP6Addr     contained /\s\@<=::\(\(\x\{1,4}:\)\{,6}\x\{1,4}\|\(\x\{1,4}:\)\{,5}\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\>/
"   1111::[...:]8               1111::[...:]127.0.0.1
syn match       zoneIP6Addr     contained /\<\(\x\{1,4}:\)\{1}:\(\(\x\{1,4}:\)\{,5}\x\{1,4}\|\(\x\{1,4}:\)\{,4}\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\>/
"   1111:2::[...:]8             1111:2::[...:]127.0.0.1
syn match       zoneIP6Addr     contained /\<\(\x\{1,4}:\)\{2}:\(\(\x\{1,4}:\)\{,4}\x\{1,4}\|\(\x\{1,4}:\)\{,3}\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\>/
"   1111:2:3::[...:]8           1111:2:3::[...:]127.0.0.1
syn match       zoneIP6Addr     contained /\<\(\x\{1,4}:\)\{3}:\(\(\x\{1,4}:\)\{,3}\x\{1,4}\|\(\x\{1,4}:\)\{,2}\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\>/
"   1111:2:3:4::[...:]8         1111:2:3:4::[...:]127.0.0.1
syn match       zoneIP6Addr     contained /\<\(\x\{1,4}:\)\{4}:\(\(\x\{1,4}:\)\{,2}\x\{1,4}\|\(\x\{1,4}:\)\{,1}\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\>/
"   1111:2:3:4:5::[...:]8       1111:2:3:4:5::127.0.0.1
syn match       zoneIP6Addr     contained /\<\(\x\{1,4}:\)\{5}:\(\(\x\{1,4}:\)\{,1}\x\{1,4}\|\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\>/
"   1111:2:3:4:5:6::8           -
syn match       zoneIP6Addr     contained /\<\(\x\{1,4}:\)\{6}:\x\{1,4}\>/
"   1111[:...]::                -
syn match       zoneIP6Addr     contained /\<\(\x\{1,4}:\)\{1,7}:\(\s\|;\|$\)\@=/

syn match       zoneText        contained /"\([^"\\]\|\\.\)*"\(\s\|;\|$\)\@=/
syn match       zoneNumber      contained /\<[0-9]\+\(\s\|;\|$\)\@=/
syn match       zoneSerial      contained /\<[0-9]\{9,10}\(\s\|;\|$\)\@=/

syn match       zoneErrParen    /)/
syn region      zoneParen       contained start="(" end=")" contains=zoneSerial,zoneTTL,zoneNumber,zoneComment
syn match       zoneComment     /;.*/

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_bind_zone_syn_inits")
  if version < 508
    let did_bind_zone_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink zoneDirective    Macro
  
  HiLink zoneUnknown      Error
  
  HiLink zoneOrigin       Statement
  HiLink zoneOwnerName    Statement
  HiLink zoneDomain       Identifier
  
  HiLink zoneSpecial      Special
  HiLink zoneTTL          Constant
  HiLink zoneClass        Include
  HiLink zoneRRType       Type
  
  HiLink zoneIPAddr       Number
  HiLink zoneIP6Addr      Number
  HiLink zoneText         String
  HiLink zoneNumber       Number
  HiLink zoneSerial       Special
  
  HiLink zoneErrParen     Error
  HiLink zoneComment      Comment

  delcommand HiLink
endif

let b:current_syntax = "bindzone"

" vim:sts=2 sw=2
