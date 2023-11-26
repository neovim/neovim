" Vim syntax file
" Language:	RCS log output
" Maintainer:	Joe Karthauser <joe@freebsd.org>
" Last Change:	2001 May 09

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn match rcslogRevision	"^revision.*$"
syn match rcslogFile		"^RCS file:.*"
syn match rcslogDate		"^date: .*$"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link rcslogFile		Type
hi def link rcslogRevision	Constant
hi def link rcslogDate		Identifier


let b:current_syntax = "rcslog"

" vim: ts=8
