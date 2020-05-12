" Vim syntax file
" Language:	Dylan
" Authors:	Justus Pendleton <justus@acm.org>
" Last Change:	Fri Sep 29 13:53:27 PDT 2000
"

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

syn region	dylanintrInfo		matchgroup=Statement start="^" end=":" oneline
syn match	dylanintrInterface	"define interface"
syn match	dylanintrClass		"<.*>"
syn region	dylanintrType		start=+"+ skip=+\\\\\|\\"+ end=+"+

syn region	dylanintrIncluded	contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match	dylanintrIncluded	contained "<[^>]*>"
syn match	dylanintrInclude	"^\s*#\s*include\>\s*["<]" contains=intrIncluded

"syn keyword intrMods pointer struct

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link dylanintrInfo		Special
hi def link dylanintrInterface	Operator
hi def link dylanintrMods		Type
hi def link dylanintrClass		StorageClass
hi def link dylanintrType		Type
hi def link dylanintrIncluded	String
hi def link dylanintrInclude	Include


let b:current_syntax = "dylanintr"

" vim:ts=8
