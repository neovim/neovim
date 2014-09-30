" Vim syntax file
" Language:	RCS log output
" Maintainer:	Joe Karthauser <joe@freebsd.org>
" Last Change:	2001 May 09

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn match rcslogRevision	"^revision.*$"
syn match rcslogFile		"^RCS file:.*"
syn match rcslogDate		"^date: .*$"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_rcslog_syntax_inits")
  if version < 508
    let did_rcslog_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink rcslogFile		Type
  HiLink rcslogRevision	Constant
  HiLink rcslogDate		Identifier

  delcommand HiLink
endif

let b:current_syntax = "rcslog"

" vim: ts=8
