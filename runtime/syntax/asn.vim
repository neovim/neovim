" Vim syntax file
" Language:	ASN.1
" Maintainer:	Claudio Fleiner <claudio@fleiner.com>
" URL:		http://www.fleiner.com/vim/syntax/asn.vim
" Last Change:	2012 Oct 05

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" keyword definitions
syn keyword asnExternal		DEFINITIONS BEGIN END IMPORTS EXPORTS FROM
syn match   asnExternal		"\<IMPLICIT\s\+TAGS\>"
syn match   asnExternal		"\<EXPLICIT\s\+TAGS\>"
syn keyword asnFieldOption	DEFAULT OPTIONAL
syn keyword asnTagModifier	IMPLICIT EXPLICIT
syn keyword asnTypeInfo		ABSENT PRESENT SIZE UNIVERSAL APPLICATION PRIVATE
syn keyword asnBoolValue	TRUE FALSE
syn keyword asnNumber		MIN MAX
syn match   asnNumber		"\<PLUS-INFINITY\>"
syn match   asnNumber		"\<MINUS-INFINITY\>"
syn keyword asnType		INTEGER REAL STRING BIT BOOLEAN OCTET NULL EMBEDDED PDV
syn keyword asnType		BMPString IA5String TeletexString GeneralString GraphicString ISO646String NumericString PrintableString T61String UniversalString VideotexString VisibleString
syn keyword asnType		ANY DEFINED
syn match   asnType		"\.\.\."
syn match   asnType		"OBJECT\s\+IDENTIFIER"
syn match   asnType		"TYPE-IDENTIFIER"
syn keyword asnType		UTF8String
syn keyword asnStructure	CHOICE SEQUENCE SET OF ENUMERATED CONSTRAINED BY WITH COMPONENTS CLASS

" Strings and constants
syn match   asnSpecial		contained "\\\d\d\d\|\\."
syn region  asnString		start=+"+  skip=+\\\\\|\\"+  end=+"+  contains=asnSpecial
syn match   asnCharacter	"'[^\\]'"
syn match   asnSpecialCharacter "'\\.'"
syn match   asnNumber		"-\=\<\d\+L\=\>\|0[xX][0-9a-fA-F]\+\>"
syn match   asnLineComment	"--.*"
syn match   asnLineComment	"--.*--"

syn match asnDefinition "^\s*[a-zA-Z][-a-zA-Z0-9_.\[\] \t{}]* *::="me=e-3 contains=asnType
syn match asnBraces     "[{}]"

syn sync ccomment asnComment

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
hi def link asnDefinition	Function
hi def link asnBraces		Function
hi def link asnStructure	Statement
hi def link asnBoolValue	Boolean
hi def link asnSpecial		Special
hi def link asnString		String
hi def link asnCharacter	Character
hi def link asnSpecialCharacter	asnSpecial
hi def link asnNumber		asnValue
hi def link asnComment		Comment
hi def link asnLineComment	asnComment
hi def link asnType		Type
hi def link asnTypeInfo		PreProc
hi def link asnValue		Number
hi def link asnExternal		Include
hi def link asnTagModifier	Function
hi def link asnFieldOption	Type

let &cpo = s:cpo_save
unlet s:cpo_save
let b:current_syntax = "asn"

" vim: ts=8
