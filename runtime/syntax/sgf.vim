" Vim syntax file
" Language:	Smart Game Format
" Maintainer:	Borys Lykah
" Last Change:	2026 May 30

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn match sgfDelimiter "[();]"

syn keyword sgfMoveProp B W nextgroup=sgfValue skipwhite
syn keyword sgfSetupProp AB AE AW PL nextgroup=sgfValue skipwhite
syn keyword sgfMarkupProp AR CR DD DM FG GB GW HO LB LN MA SL SQ TR UC VW nextgroup=sgfValue skipwhite
syn keyword sgfRootProp AP CA FF GM ST SZ nextgroup=sgfValue skipwhite
syn keyword sgfGameInfoProp AN BR BT CP DT EV GC GN HA KM ON OT PB PC PW RE RO RU SO TM US WR WT nextgroup=sgfValue skipwhite
syn keyword sgfCommentProp C nextgroup=sgfCommentValue skipwhite

syn match sgfProperty "\<[A-Za-z]\+\ze\s*\[" nextgroup=sgfValue skipwhite

syn match sgfEscape "\\." contained
syn region sgfValue contained matchgroup=sgfBracket start="\[" end="\]" skip="\\\\\|\\\]" contains=sgfEscape keepend nextgroup=sgfValue skipwhite
syn region sgfCommentValue contained matchgroup=sgfBracket start="\[" end="\]" skip="\\\\\|\\\]" contains=sgfEscape,@Spell keepend nextgroup=sgfCommentValue skipwhite

hi def link sgfDelimiter Delimiter
hi def link sgfMoveProp Statement
hi def link sgfSetupProp Type
hi def link sgfMarkupProp Identifier
hi def link sgfRootProp PreProc
hi def link sgfGameInfoProp Label
hi def link sgfCommentProp Comment
hi def link sgfProperty Identifier
hi def link sgfBracket Delimiter
hi def link sgfEscape SpecialChar
hi def link sgfValue String
hi def link sgfCommentValue Comment

let b:current_syntax = "sgf"

" vim: ts=8
