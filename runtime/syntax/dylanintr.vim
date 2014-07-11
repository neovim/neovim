" Vim syntax file
" Language:	Dylan
" Authors:	Justus Pendleton <justus@acm.org>
" Last Change:	Fri Sep 29 13:53:27 PDT 2000
"

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_dylan_intr_syntax_inits")
  if version < 508
    let did_dylan_intr_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink dylanintrInfo		Special
  HiLink dylanintrInterface	Operator
  HiLink dylanintrMods		Type
  HiLink dylanintrClass		StorageClass
  HiLink dylanintrType		Type
  HiLink dylanintrIncluded	String
  HiLink dylanintrInclude	Include

  delcommand HiLink
endif

let b:current_syntax = "dylanintr"

" vim:ts=8
