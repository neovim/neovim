" Vim syntax file
" Language:	PPD (PostScript printer description) file
" Maintainer:	Bjoern Jacke <bjacke@suse.de>
" Last Change:	2001-10-06

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif


syn match	ppdComment	"^\*%.*"
syn match	ppdDef		"\*[a-zA-Z0-9]\+"
syn match	ppdDefine	"\*[a-zA-Z0-9\-_]\+:"
syn match	ppdUI		"\*[a-zA-Z]*\(Open\|Close\)UI"
syn match	ppdUIGroup	"\*[a-zA-Z]*\(Open\|Close\)Group"
syn match	ppdGUIText	"/.*:"
syn match	ppdContraints	"^*UIConstraints:"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet


hi def link ppdComment		Comment
hi def link ppdDefine		Statement
hi def link ppdUI			Function
hi def link ppdUIGroup		Function
hi def link ppdDef			String
hi def link ppdGUIText		Type
hi def link ppdContraints		Special


let b:current_syntax = "ppd"

" vim: ts=8
