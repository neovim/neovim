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


hi def link ldifAttribute		Type
hi def link ldifOption		Identifier
hi def link ldifPunctuation	Normal
hi def link ldifStringValue	String
hi def link ldifBase64Value	Special
hi def link ldifFileValue		Special
hi def link ldifComment		Comment


let b:current_syntax = "ldif"
