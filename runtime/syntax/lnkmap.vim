" Vim syntax file
" Language:	TI Linker map
" Document:	https://downloads.ti.com/docs/esd/SPRUI03A/Content/SPRUI03A_HTML/linker_description.html
" Maintainer:	Wu, Zhenyu <wuzhenyu@ustc.edu>
" Last Change:	2024 Dec 30

if exists("b:current_syntax")
  finish
endif

syn match lnkmapTime			">> .*$"
syn region lnkmapHeadline		start="^\*\+$" end="^\*\+$"
syn match lnkmapHeadline		"^[A-Z][-A-Z0-9 ']*\ze\%(:\|$\)"
syn match lnkmapSectionDelim		"^=\+$"
syn match lnkmapTableDelim		"\%(^\|\s\)\zs---*\ze\%($\|\s\)"
syn match lnkmapNumber			"\%(^\|\s\)\zs[0-9a-f]\+\ze\%($\|\s\)"
syn match lnkmapSections      		'\<\.\k\+\>'
syn match lnkmapFile			'[^ =]\+\%(\.\S\+\)\+\>'
syn match lnkmapLibFile			'[^ =]\+\.lib\>'
syn match lnkmapAttrib			'\<[RWIX]\+\>'
syn match lnkmapAttrib			'\s\zs--HOLE--\ze\%\(\s\|$\)'
syn keyword lnkmapAttrib		UNINITIALIZED DESCT


hi def link lnkmapTime			Comment
hi def link lnkmapHeadline		Title
hi def link lnkmapSectionDelim		PreProc
hi def link lnkmapTableDelim		PreProc
hi def link lnkmapNumber		Number
hi def link lnkmapSections		Macro
hi def link lnkmapFile			String
hi def link lnkmapLibFile		Special
hi def link lnkmapAttrib		Type

let b:current_syntax = "lnkmap"
