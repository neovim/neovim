" Vim syntax file
" Language:	LDAP LDIF
" Maintainer:	Zak Johnson <zakj@nox.cx>
" Last Change:	2003-12-30

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn sync minlines=10 linebreaks=1

syn match ldifAttribute /^[^ #][^:]*/ contains=ldifOption display
syn match ldifOption /;[^:]\+/ contained contains=ldifPunctuation display
syn match ldifPunctuation /;/ contained display

syn region ldifStringValue matchgroup=ldifPunctuation start=/: /  end=/\_$/ skip=/\n /
syn region ldifBase64Value matchgroup=ldifPunctuation start=/:: / end=/\_$/ skip=/\n /
syn region ldifFileValue   matchgroup=ldifPunctuation start=/:< / end=/\_$/ skip=/\n /

syn region ldifComment start=/^#/ end=/\_$/ skip=/\n /

command -nargs=+ HiLink hi def link <args>

HiLink ldifAttribute		Type
HiLink ldifOption		Identifier
HiLink ldifPunctuation	Normal
HiLink ldifStringValue	String
HiLink ldifBase64Value	Special
HiLink ldifFileValue		Special
HiLink ldifComment		Comment

delcommand HiLink

let b:current_syntax = "ldif"
