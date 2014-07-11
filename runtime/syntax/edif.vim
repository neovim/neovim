" Vim syntax file
" Language:     EDIF (Electronic Design Interchange Format)
" Maintainer:   Artem Zankovich <z_artem@hotbox.ru>
" Last Change:  Oct 14, 2002
"
" Supported standarts are:
"   ANSI/EIA Standard 548-1988 (EDIF Version 2 0 0)
"   IEC 61690-1 (EDIF Version 3 0 0)
"   IEC 61690-2 (EDIF Version 4 0 0)

" Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

if version >= 600
 setlocal iskeyword=48-57,-,+,A-Z,a-z,_,&
else
 set iskeyword=A-Z,a-z,_,&
endif

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
if version < 600
  syntax sync maxlines=250
else
  syntax sync fromstart
endif

" Define the default highlighting.
if version >= 508 || !exists("did_edif_syntax_inits")
  if version < 508
    let did_edif_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink edifInString		SpecialChar
  HiLink edifKeyword		Keyword
  HiLink edifNumber		Number
  HiLink edifInStringError	edifError
  HiLink edifError		Error
  HiLink edifString		String
  delcommand HiLink
endif

let b:current_syntax = "edif"
