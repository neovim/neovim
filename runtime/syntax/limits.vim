" Vim syntax file
" Language:             limits(5) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword limitsTodo    contained TODO FIXME XXX NOTE

syn region  limitsComment display oneline start='^\s*#' end='$'
                          \ contains=limitsTodo,@Spell

syn match   limitsBegin   display '^'
                          \ nextgroup=limitsUser,limitsDefault,limitsComment
                          \ skipwhite

syn match   limitsUser    contained '[^ \t#*]\+'
                          \ nextgroup=limitsLimit,limitsDeLimit skipwhite

syn match   limitsDefault contained '*'
                          \ nextgroup=limitsLimit,limitsDeLimit skipwhite

syn match   limitsLimit   contained '[ACDFMNRSTUKLP]' nextgroup=limitsNumber
syn match   limitsDeLimit contained '-'

syn match   limitsNumber  contained '\d\+\>' nextgroup=limitsLimit skipwhite

hi def link limitsTodo    Todo
hi def link limitsComment Comment
hi def link limitsUser    Keyword
hi def link limitsDefault Macro
hi def link limitsLimit   Identifier
hi def link limitsDeLimit Special
hi def link limitsNumber  Number

let b:current_syntax = "limits"

let &cpo = s:cpo_save
unlet s:cpo_save
