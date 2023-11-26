" Vim syntax file
" Language:     EDIF (Electronic Design Interchange Format)
" Maintainer:   Artem Zankovich <z_artem@hotbox.ru>
" Last Change:  Oct 14, 2002
"
" Supported standarts are:
"   ANSI/EIA Standard 548-1988 (EDIF Version 2 0 0)
"   IEC 61690-1 (EDIF Version 3 0 0)
"   IEC 61690-2 (EDIF Version 4 0 0)

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

setlocal iskeyword=48-57,-,+,A-Z,a-z,_,&

syn region	edifList	matchgroup=Delimiter start="(" end=")" contains=edifList,edifKeyword,edifString,edifNumber

" Strings
syn match       edifInStringError    /%/ contained
syn match       edifInString    /%\s*\d\+\s*%/ contained
syn region      edifString      start=/"/ end=/"/ contains=edifInString,edifInStringError contained

" Numbers
syn match       edifNumber      "\<[-+]\=[0-9]\+\>"

" Keywords
syn match       edifKeyword     "(\@<=\s*[a-zA-Z&][a-zA-Z_0-9]*\>" contained

syn match       edifError       ")"

" synchronization
syntax sync fromstart

" Define the default highlighting.

hi def link edifInString		SpecialChar
hi def link edifKeyword		Keyword
hi def link edifNumber		Number
hi def link edifInStringError	edifError
hi def link edifError		Error
hi def link edifString		String

let b:current_syntax = "edif"
