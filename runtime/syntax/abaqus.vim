" Vim syntax file
" Language:	Abaqus finite element input file (www.hks.com)
" Maintainer:	Carl Osterwisch <osterwischc@asme.org>
" Last Change:	2002 Feb 24
" Remark:	Huge improvement in folding performance--see filetype plugin

" quit when a syntax file was already loaded
if exists("b:current_syntax")
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
" Only when an item doesn't have highlighting yet
command -nargs=+ HiLink hi def link <args>

" The default methods for highlighting.  Can be overridden later
HiLink abaqusComment	Comment
HiLink abaqusKeyword	Statement
HiLink abaqusParameter	Identifier
HiLink abaqusValue	Constant
HiLink abaqusBadLine    Error

delcommand HiLink

let b:current_syntax = "abaqus"
