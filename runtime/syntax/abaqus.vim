" Vim syntax file
" Language:	Abaqus finite element input file (www.hks.com)
" Maintainer:	Carl Osterwisch <osterwischc@asme.org>
" Last Change:	2002 Feb 24
" Remark:	Huge improvement in folding performance--see filetype plugin

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Abaqus comment lines
syn match abaqusComment	"^\*\*.*$"

" Abaqus keyword lines
syn match abaqusKeywordLine "^\*\h.*" contains=abaqusKeyword,abaqusParameter,abaqusValue display
syn match abaqusKeyword "^\*\h[^,]*" contained display
syn match abaqusParameter ",[^,=]\+"lc=1 contained display
syn match abaqusValue	"=\s*[^,]*"lc=1 contained display

" Illegal syntax
syn match abaqusBadLine	"^\s\+\*.*" display

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_abaqus_syn_inits")
	if version < 508
		let did_abaqus_syn_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
	endif

	" The default methods for highlighting.  Can be overridden later
	HiLink abaqusComment	Comment
	HiLink abaqusKeyword	Statement
	HiLink abaqusParameter	Identifier
	HiLink abaqusValue	Constant
	HiLink abaqusBadLine    Error

	delcommand HiLink
endif

let b:current_syntax = "abaqus"
