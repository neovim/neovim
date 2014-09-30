" Vim syntax file
" Language:	ASN.1
" Maintainer:	Claudio Fleiner <claudio@fleiner.com>
" URL:		http://www.fleiner.com/vim/syntax/asn.vim
" Last Change:	2012 Oct 05

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_asn_syn_inits")
  if version < 508
    let did_asn_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif
  HiLink asnDefinition	Function
  HiLink asnBraces		Function
  HiLink asnStructure	Statement
  HiLink asnBoolValue	Boolean
  HiLink asnSpecial		Special
  HiLink asnString		String
  HiLink asnCharacter	Character
  HiLink asnSpecialCharacter	asnSpecial
  HiLink asnNumber		asnValue
  HiLink asnComment		Comment
  HiLink asnLineComment	asnComment
  HiLink asnType		Type
  HiLink asnTypeInfo		PreProc
  HiLink asnValue		Number
  HiLink asnExternal		Include
  HiLink asnTagModifier	Function
  HiLink asnFieldOption	Type
  delcommand HiLink
endif

let &cpo = s:cpo_save
unlet s:cpo_save
let b:current_syntax = "asn"

" vim: ts=8
