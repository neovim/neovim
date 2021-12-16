" Vim syntax file
" Language:         Texinfo (documentation format)
" Maintainer:       Robert Dodier <robert.dodier@gmail.com>
" Latest Revision:  2021-12-15

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match texinfoControlSequence display '\(@end [a-zA-Z@]\+\|@[a-zA-Z@]\+\)'

syn match texinfoComment         display '^\s*\(@comment\|@c\)\>.*$'

syn region texinfoCode matchgroup=texinfoControlSequence start="@code{" end="}" contains=ALL
syn region texinfoVerb matchgroup=texinfoControlSequence start="@verb{" end="}" contains=ALL

syn region texinfoArgument matchgroup=texinfoBrace start="{" end="}" contains=ALLBUT

syn region texinfoExample matchgroup=texinfoControlSequence start="^@example\s*$" end="^@end example\s*$" contains=ALL

syn region texinfoVerbatim matchgroup=texinfoControlSequence start="^@verbatim\s*$" end="^@end verbatim\s*$"

syn region texinfoMenu matchgroup=texinfoControlSequence start="^@menu\s*$" end="^@end menu\s*$"

if exists("g:texinfo_delimiters")
  syn match texinfoDelimiter display '[][{}]'
endif

hi def link texinfoDelimiter       Delimiter
hi def link texinfoComment         Comment
hi def link texinfoControlSequence Identifier
hi def link texinfoBrace           Operator
hi def link texinfoArgument        Special
hi def link texinfoExample         String
hi def link texinfoVerbatim        String
hi def link texinfoVerb            String
hi def link texinfoCode            String
hi def link texinfoMenu            String

let b:current_syntax = "texinfo"

let &cpo = s:cpo_save
unlet s:cpo_save
