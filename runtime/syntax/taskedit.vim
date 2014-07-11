" Vim syntax file
" Language:	support for 'task 42 edit'
" Maintainer:	John Florian <jflorian@doubledog.org>
" Updated:	Wed Jul  8 19:46:32 EDT 2009


" For version 5.x: Clear all syntax items.
" For version 6.x: Quit when a syntax file was already loaded.
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

syn match taskeditHeading	"^\s*#\s*Name\s\+Editable details\s*$" contained
syn match taskeditHeading	"^\s*#\s*-\+\s\+-\+\s*$" contained
syn match taskeditReadOnly	"^\s*#\s*\(UU\)\?ID:.*$" contained
syn match taskeditReadOnly	"^\s*#\s*Status:.*$" contained
syn match taskeditReadOnly	"^\s*#\s*i\?Mask:.*$" contained
syn match taskeditKey		"^ *.\{-}:" nextgroup=taskeditString
syn match taskeditComment	"^\s*#.*$"
			\	contains=taskeditReadOnly,taskeditHeading
syn match taskeditString	".*$" contained contains=@Spell


" The default methods for highlighting.  Can be overridden later.
hi def link taskeditComment	Comment
hi def link taskeditHeading	Function
hi def link taskeditKey		Statement
hi def link taskeditReadOnly	Special
hi def link taskeditString	String

let b:current_syntax = "taskedit"

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:noexpandtab
