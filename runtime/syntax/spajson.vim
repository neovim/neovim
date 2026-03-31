" Vim syntax file
" Language:	SPA JSON
" Maintainer:	David Mandelberg <david@mandelberg.org>
" Last Change:	2025 Mar 22
"
" Based on parser code:
" https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/master/spa/include/spa/utils/json-core.h

if exists("b:current_syntax")
 finish
endif
let b:current_syntax = "spajson"

syn sync minlines=500

" Treat the __BARE parser state as a keyword, to make it easier to match
" keywords and numbers only when they're not part of a larger __BARE section.
" E.g., v4l2 and pipewire-0 probably shouldn't highlight anything as
" spajsonInt.
syn iskeyword 32-126,^ ,^",^#,^:,^,,^=,^],^},^\

syn match spajsonEscape "\\["\\/bfnrt]" contained
syn match spajsonEscape "\\u[0-9A-Fa-f]\{4}" contained

syn match spajsonError "."
syn match spajsonBare "\k\+"
syn match spajsonComment "#.*$" contains=@Spell
syn region spajsonString start=/"/ skip=/\\\\\|\\"/ end=/"/ contains=spajsonEscape
syn match spajsonKeyDelimiter "[:=]"
syn region spajsonArray matchgroup=spajsonBracket start="\[" end="]" contains=ALLBUT,spajsonKeyDelimiter fold
syn region spajsonObject matchgroup=spajsonBrace start="{" end="}" contains=ALL fold
syn match spajsonFloat "\<[+-]\?[0-9]\+\(\.[0-9]*\)\?\([Ee][+-]\?[0-9]\+\)\?\>"
syn match spajsonFloat "\<[+-]\?\.[0-9]\+\([Ee][+-]\?[0-9]\+\)\?\>"
syn match spajsonInt "\<[+-]\?0[Xx][0-9A-Fa-f]\+\>"
syn match spajsonInt "\<[+-]\?[1-9][0-9]*\>"
syn match spajsonInt "\<[+-]\?0[0-7]*\>"
syn keyword spajsonBoolean true false
syn keyword spajsonNull null
syn match spajsonWhitespace "[\x00\t \r\n,]"

hi def link spajsonBoolean Boolean
hi def link spajsonBrace Delimiter
hi def link spajsonBracket Delimiter
hi def link spajsonComment Comment
hi def link spajsonError Error
hi def link spajsonEscape SpecialChar
hi def link spajsonFloat Float
hi def link spajsonInt Number
hi def link spajsonNull Constant
hi def link spajsonString String
