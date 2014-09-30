" Vim syntax file
" Language:	task data
" Maintainer:	John Florian <jflorian@doubledog.org>
" Updated:	Wed Jul  8 19:46:20 EDT 2009


" For version 5.x: Clear all syntax items.
" For version 6.x: Quit when a syntax file was already loaded.
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

" Key Names for values.
syn keyword taskdataKey		description due end entry imask mask parent
syn keyword taskdataKey		priority project recur start status tags uuid
syn match taskdataKey		"annotation_\d\+"
syn match taskdataUndo		"^time.*$"
syn match taskdataUndo		"^\(old \|new \|---\)"

" Values associated with key names.
"
" Strings
syn region taskdataString	matchgroup=Normal start=+"+ end=+"+
			\	contains=taskdataEncoded,taskdataUUID,@Spell
"
" Special Embedded Characters (e.g., "&comma;")
syn match taskdataEncoded	"&\a\+;" contained
" UUIDs
syn match taskdataUUID		"\x\{8}-\(\x\{4}-\)\{3}\x\{12}" contained


" The default methods for highlighting.  Can be overridden later.
hi def link taskdataEncoded	Function
hi def link taskdataKey		Statement
hi def link taskdataString 	String
hi def link taskdataUUID 	Special
hi def link taskdataUndo 	Type

let b:current_syntax = "taskdata"

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:noexpandtab
