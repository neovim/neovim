" Vim syntax file
" Language:	Slrn score file (based on slrn 0.9.8.0)
" Maintainer:	Preben 'Peppe' Guldberg <peppe@wielders.org>
" Last Change:	8 Oct 2004

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" characters in newsgroup names
if version < 600
  set isk=@,48-57,.,-,_,+
else
  setlocal isk=@,48-57,.,-,_,+
endif

syn match slrnscComment		"%.*$"
syn match slrnscSectionCom	".].*"lc=2

syn match slrnscGroup		contained "\(\k\|\*\)\+"
syn match slrnscNumber		contained "\d\+"
syn match slrnscDate		contained "\(\d\{1,2}[-/]\)\{2}\d\{4}"
syn match slrnscDelim		contained ":"
syn match slrnscComma		contained ","
syn match slrnscOper		contained "\~"
syn match slrnscEsc		contained "\\[ecC<>.]"
syn match slrnscEsc		contained "[?^]"
syn match slrnscEsc		contained "[^\\]$\s*$"lc=1

syn keyword slrnscInclude	contained include
syn match slrnscIncludeLine	"^\s*Include\s\+\S.*$"

syn region slrnscSection	matchgroup=slrnscSectionStd start="^\s*\[" end='\]' contains=slrnscGroup,slrnscComma,slrnscSectionCom
syn region slrnscSection	matchgroup=slrnscSectionNot start="^\s*\[\~" end='\]' contains=slrnscGroup,slrnscCommas,slrnscSectionCom

syn keyword slrnscItem		contained Age Bytes Date Expires From Has-Body Lines Message-Id Newsgroup References Subject Xref

syn match slrnscScoreItem	contained "%.*$"						skipempty nextgroup=slrnscScoreItem contains=slrnscComment
syn match slrnscScoreItem	contained "^\s*Expires:\s*\(\d\{1,2}[-/]\)\{2}\d\{4}\s*$"	skipempty nextgroup=slrnscScoreItem contains=slrnscItem,slrnscDelim,slrnscDate
syn match slrnscScoreItem	contained "^\s*\~\=\(Age\|Bytes\|Has-Body\|Lines\):\s*\d\+\s*$"	skipempty nextgroup=slrnscScoreItem contains=slrnscOper,slrnscItem,slrnscDelim,slrnscNumber
syn match slrnscScoreItemFill	contained ".*$"							skipempty nextgroup=slrnscScoreItem contains=slrnscEsc
syn match slrnscScoreItem	contained "^\s*\~\=\(Date\|From\|Message-Id\|Newsgroup\|References\|Subject\|Xref\):"	nextgroup=slrnscScoreItemFill contains=slrnscOper,slrnscItem,slrnscDelim
syn region slrnscScoreItem	contained matchgroup=Special start="^\s*\~\={::\=" end="^\s*}" skipempty nextgroup=slrnscScoreItem contains=slrnscScoreItem

syn keyword slrnscScore		contained Score
syn match slrnscScoreIdent	contained "%.*"
syn match slrnScoreLine		"^\s*Score::\=\s\+=\=[-+]\=\d\+\s*\(%.*\)\=$" skipempty nextgroup=slrnscScoreItem contains=slrnscScore,slrnscDelim,slrnscOper,slrnscNumber,slrnscScoreIdent

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_slrnsc_syntax_inits")
  if version < 508
    let did_slrnsc_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink slrnscComment		Comment
  HiLink slrnscSectionCom	slrnscComment
  HiLink slrnscGroup		String
  HiLink slrnscNumber		Number
  HiLink slrnscDate		Special
  HiLink slrnscDelim		Delimiter
  HiLink slrnscComma		SpecialChar
  HiLink slrnscOper		SpecialChar
  HiLink slrnscEsc		String
  HiLink slrnscSectionStd	Type
  HiLink slrnscSectionNot	Delimiter
  HiLink slrnscItem		Statement
  HiLink slrnscScore		Keyword
  HiLink slrnscScoreIdent	Identifier
  HiLink slrnscInclude		Keyword

  delcommand HiLink
endif

let b:current_syntax = "slrnsc"

"EOF	vim: ts=8 noet tw=200 sw=8 sts=0
