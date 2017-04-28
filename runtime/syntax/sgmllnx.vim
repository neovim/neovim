" Vim syntax file
" Language:	SGML-linuxdoc (supported by old sgmltools-1.x)
" Maintainer:	SungHyun Nam <goweol@gmail.com>
" Last Change:	2013 May 13

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

" tags
syn region sgmllnxEndTag	start=+</+    end=+>+	contains=sgmllnxTagN,sgmllnxTagError
syn region sgmllnxTag	start=+<[^/]+ end=+>+	contains=sgmllnxTagN,sgmllnxTagError
syn match  sgmllnxTagN	contained +<\s*[-a-zA-Z0-9]\++ms=s+1	contains=sgmllnxTagName
syn match  sgmllnxTagN	contained +</\s*[-a-zA-Z0-9]\++ms=s+2	contains=sgmllnxTagName

syn region sgmllnxTag2	start=+<\s*[a-zA-Z]\+/+ keepend end=+/+	contains=sgmllnxTagN2
syn match  sgmllnxTagN2	contained +/.*/+ms=s+1,me=e-1

syn region sgmllnxSpecial	oneline start="&" end=";"

" tag names
syn keyword sgmllnxTagName contained article author date toc title sect verb
syn keyword sgmllnxTagName contained abstract tscreen p itemize item enum
syn keyword sgmllnxTagName contained descrip quote htmlurl code ref
syn keyword sgmllnxTagName contained tt tag bf it url
syn match   sgmllnxTagName contained "sect\d\+"

" Comments
syn region sgmllnxComment start=+<!--+ end=+-->+
syn region sgmllnxDocType start=+<!doctype+ end=+>+

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
command -nargs=+ HiLink hi def link <args>

HiLink sgmllnxTag2	    Function
HiLink sgmllnxTagN2	    Function
HiLink sgmllnxTag	    Special
HiLink sgmllnxEndTag	    Special
HiLink sgmllnxParen	    Special
HiLink sgmllnxEntity	    Type
HiLink sgmllnxDocEnt	    Type
HiLink sgmllnxTagName	    Statement
HiLink sgmllnxComment	    Comment
HiLink sgmllnxSpecial	    Special
HiLink sgmllnxDocType	    PreProc
HiLink sgmllnxTagError    Error

delcommand HiLink

let b:current_syntax = "sgmllnx"

" vim:set tw=78 ts=8 sts=2 sw=2 noet:
