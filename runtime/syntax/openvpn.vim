" Vim syntax file
" Language:	OpenVPN
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Filenames:	*.ovpn
" Last Change:	2022 Oct 16

if exists('b:current_syntax')
    finish
endif

let s:cpo_save = &cpoptions
set cpoptions&vim

" Options
syntax match openvpnOption /^[a-z-]\+/
            \ skipwhite nextgroup=openvpnArgList
syntax match openvpnArgList /.*$/ transparent contained
            \ contains=openvpnArgument,openvpnNumber,
            \ openvpnIPv4Address,openvpnIPv6Address,
            \ openvpnSignal,openvpnComment

" Arguments
syntax match openvpnArgument /[^\\"' \t]\+/
            \ contained contains=openvpnEscape
syntax region openvpnArgument matchgroup=openvpnQuote
            \ start=/"/ skip=/\\"/ end=/"/
            \ oneline contained contains=openvpnEscape
syntax region openvpnArgument matchgroup=openvpnQuote
            \ start=/'/ skip=/\\'/ end=/'/
            \ oneline contained
syntax match openvpnEscape /\\[\\" \t]/ contained

" Numbers
syntax match openvpnNumber /\<[1-9][0-9]*\(\.[0-9]\+\)\?\>/ contained

" Signals
syntax match openvpnSignal /SIG\(HUP\|INT\|TERM\|USER[12]\)/ contained

" IP addresses
syntax match openvpnIPv4Address /\(\d\{1,3}\.\)\{3}\d\{1,3}/
            \ contained nextgroup=openvpnSlash
syntax match openvpnIPv6Address /\([A-F0-9]\{1,4}:\)\{7}\[A-F0-9]\{1,4}/
            \ contained nextgroup=openvpnSlash
syntax match openvpnSlash "/" contained
            \ nextgroup=openvpnIPv4Address,openvpnIPv6Address,openvpnNumber

" Inline files
syntax region openvpnInline matchgroup=openvpnTag
            \ start=+^<\z([a-z-]\+\)>+ end=+^</\z1>+

" Comments
syntax keyword openvpnTodo contained TODO FIXME NOTE XXX
syntax match openvpnComment /^[;#].*$/ contains=openvpnTodo
syntax match openvpnComment /\s\+\zs[;#].*$/ contains=openvpnTodo

hi def link openvpnArgument String
hi def link openvpnComment Comment
hi def link openvpnEscape SpecialChar
hi def link openvpnIPv4Address Constant
hi def link openvpnIPv6Address Constant
hi def link openvpnNumber Number
hi def link openvpnOption Keyword
hi def link openvpnQuote Quote
hi def link openvpnSignal Special
hi def link openvpnSlash Delimiter
hi def link openvpnTag Tag
hi def link openvpnTodo Todo

let b:current_syntax = 'openvpn'

let &cpoptions = s:cpo_save
unlet s:cpo_save
