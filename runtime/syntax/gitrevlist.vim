" Vim syntax file
" Language:     Git revision list
" Author:       Fionn Fitzmaurice (github.com/fionn)
" Maintainer:   Fionn Fitzmaurice (github.com/fionn)
" License:      Vim & Apache 2.0

if exists("b:current_syntax")
    finish
endif

syn match gitrevlistHash "\<\x\{40}\>\|\<\x\{64}\>" contains=@NoSpell nextgroup=gitrevlistComment skipwhite
syn match gitrevlistComment "#.*$"

hi def link gitrevlistHash Identifier
hi def link gitrevlistComment Comment

let b:current_syntax = "gitrevlist"
