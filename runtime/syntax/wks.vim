" Vim syntax file
" Language:	OpenEmbedded Image Creator (WIC) Kickstarter files wks
" Maintainer:	Anakin Childerhose <anakin@childerhose.ca>
" Last Change:	2026 Mar 23

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case match

syn match wksComment "#.*$"
syn match wksCommand "\<bootloader\>"
syn match wksCommand "\<\(part\|partition\)\>" skipwhite nextgroup=wksMountPoint
syn match wksMountPoint "\(/[^ \t]*\|swap\)" contained

syn match wksOption "--[a-zA-Z_-]\+"

hi def link wksComment    Comment
hi def link wksCommand    Statement
hi def link wksMountPoint Identifier
hi def link wksOption     Special

let b:current_syntax = "wks"
let &cpo = s:cpo_save
unlet s:cpo_save
