" Vim syntax file
" Language:	Abaqus finite element input file (www.hks.com)
" Maintainer:	Carl Osterwisch <costerwi@gmail.com>
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

" The default methods for highlighting.  Can be overridden later
hi def link abaqusComment	Comment
hi def link abaqusKeyword	Statement
hi def link abaqusParameter	Identifier
hi def link abaqusValue		Constant
hi def link abaqusBadLine    	Error

let b:current_syntax = "abaqus"
