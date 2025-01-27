" Vim syntax file
" Language:	po (gettext)
" Maintainer:	Dwayne Bailey <dwayne@translate.org.za>
" Last Change:	2024 Nov 28
" Contributors: Dwayne Bailey (Most advanced syntax highlighting)
"               Leonardo Fontenelle (Spell checking)
"               Nam SungHyun <namsh@kldp.org> (Original maintainer)
"               Eisuke Kawashima (add format-flags: #16132)

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

syn sync minlines=10

" Identifiers
syn match  poStatementMsgCTxt "^msgctxt"
syn match  poStatementMsgidplural "^msgid_plural" contained
syn match  poPluralCaseN "[0-9]" contained
syn match  poStatementMsgstr "^msgstr\(\[[0-9]\]\)" contains=poPluralCaseN

" Simple HTML and XML highlighting
syn match  poHtml "<\_[^<>]\+>" contains=poHtmlTranslatables,poLineBreak
syn match  poHtmlNot +"<[^<]\+>"+ms=s+1,me=e-1
syn region poHtmlTranslatables start=+\(abbr\|alt\|content\|summary\|standby\|title\)=\\"+ms=e-1 end=+\\"+ contained contains=@Spell
syn match poLineBreak +"\n"+ contained

" Translation blocks
syn region     poMsgCTxt	matchgroup=poStatementMsgCTxt start=+^msgctxt "+rs=e-1 matchgroup=poStringCTxt end=+^msgid "+me=s-1 contains=poStringCTxt
syn region     poMsgID	matchgroup=poStatementMsgid start=+^msgid "+rs=e-1 matchgroup=poStringID end=+^msgstr\(\|\[[\]0\[]\]\) "+me=s-1 contains=poStringID,poStatementMsgidplural,poStatementMsgid
syn region     poMsgSTR	matchgroup=poStatementMsgstr start=+^msgstr\(\|\[[\]0\[]\]\) "+rs=e-1 matchgroup=poStringSTR end=+\n\n+me=s-1 contains=poStringSTR,poStatementMsgstr
syn region poStringCTxt	start=+"+ skip=+\\\\\|\\"+ end=+"+
syn region poStringID	start=+"+ skip=+\\\\\|\\"+ end=+"+ contained
                            \ contains=poSpecial,poFormat,poCommentKDE,poPluralKDE,poKDEdesktopFile,poHtml,poAcceleratorId,poHtmlNot,poVariable
syn region poStringSTR	start=+"+ skip=+\\\\\|\\"+ end=+"+ contained
                            \ contains=@Spell,poSpecial,poFormat,poHeaderItem,poCommentKDEError,poHeaderUndefined,poPluralKDEError,poMsguniqError,poKDEdesktopFile,poHtml,poAcceleratorStr,poHtmlNot,poVariable

" Header and Copyright
syn match     poHeaderItem "\(Project-Id-Version\|Report-Msgid-Bugs-To\|POT-Creation-Date\|PO-Revision-Date\|Last-Translator\|Language-Team\|Language\|MIME-Version\|Content-Type\|Content-Transfer-Encoding\|Plural-Forms\|X-Generator\): " contained
syn match     poHeaderUndefined "\(PACKAGE VERSION\|YEAR-MO-DA HO:MI+ZONE\|FULL NAME <EMAIL@ADDRESS>\|LANGUAGE <LL@li.org>\|CHARSET\|ENCODING\|INTEGER\|EXPRESSION\)" contained
syn match     poCopyrightUnset "SOME DESCRIPTIVE TITLE\|FIRST AUTHOR <EMAIL@ADDRESS>, YEAR\|Copyright (C) YEAR Free Software Foundation, Inc\|YEAR THE PACKAGE\'S COPYRIGHT HOLDER\|PACKAGE" contained

" Translation comment block including: translator comment, automatic comments, flags and locations
syn match     poComment "^#.*$"
syn keyword   poFlagFuzzy fuzzy contained

syn match     poFlagFormat /\<\%(no-\)\?awk-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?boost-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?c++-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?c-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?csharp-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?elisp-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?gcc-internal-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?gfc-internal-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?java-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?java-printf-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?javascript-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?kde-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?librep-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?lisp-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?lua-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?objc-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?object-pascal-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?perl-brace-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?perl-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?php-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?python-brace-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?python-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?qt-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?qt-plural-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?ruby-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?scheme-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?sh-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?smalltalk-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?tcl-format\>/ contained
syn match     poFlagFormat /\<\%(no-\)\?ycp-format\>/ contained

syn match     poCommentTranslator "^# .*$" contains=poCopyrightUnset
syn match     poCommentAutomatic "^#\..*$"
syn match     poCommentSources	"^#:.*$"
syn match     poCommentFlags "^#,.*$" contains=poFlagFuzzy,poFlagFormat
syn match     poCommentPrevious "^#|.*$"

" Translations (also includes header fields as they appear in a translation msgstr)
syn region poCommentKDE	  start=+"_: +ms=s+1 end="\\n" end="\"\n^msgstr"me=s-1 contained
syn region poCommentKDEError  start=+"\(\|\s\+\)_:+ms=s+1 end="\\n" end=+"\n\n+me=s-1 contained
syn match  poPluralKDE   +"_n: +ms=s+1 contained
syn region poPluralKDEError   start=+"\(\|\s\+\)_n:+ms=s+1 end="\"\n\n"me=s-1 contained
syn match  poSpecial	contained "\\\(x\x\+\|\o\{1,3}\|.\|$\)"
syn match  poFormat	"%\(\d\+\$\)\=[-+' #0*]*\(\d*\|\*\|\*\d\+\$\)\(\.\(\d*\|\*\|\*\d\+\$\)\)\=\([hlL]\|ll\)\=\([diuoxXfeEgGcCsSpn]\|\[\^\=.[^]]*\]\)" contained
syn match  poFormat	"%%" contained

" msguniq and msgcat conflicts
syn region poMsguniqError matchgroup=poMsguniqErrorMarkers  start="#-#-#-#-#"  end='#\("\n"\|\)-\("\n"\|\)#\("\n"\|\)-\("\n"\|\)#\("\n"\|\)-\("\n"\|\)#\("\n"\|\)-\("\n"\|\)#\("\n"\|\)\\n' contained

" Obsolete messages
syn match poObsolete "^#\~.*$"

" KDE Name= handling
syn match poKDEdesktopFile "\"\(Name\|Comment\|GenericName\|Description\|Keywords\|About\)="ms=s+1,me=e-1

" Accelerator keys - this messes up if the preceding or following char is a multibyte unicode char
syn match poAcceleratorId  contained "[^&_~][&_~]\(\a\|\d\)[^:]"ms=s+1,me=e-1
syn match poAcceleratorStr  contained "[^&_~][&_~]\(\a\|\d\)[^:]"ms=s+1,me=e-1 contains=@Spell

" Variables simple
syn match poVariable contained "%\d"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link poCommentSources    PreProc
hi def link poComment	     Comment
hi def link poCommentAutomatic  Comment
hi def link poCommentTranslator Comment
hi def link poCommentFlags      Special
hi def link poCommentPrevious   Comment
hi def link poCopyrightUnset    Todo
hi def link poFlagFuzzy         Todo
hi def link poFlagFormat        Todo
hi def link poObsolete         Comment

hi def link poStatementMsgid   Statement
hi def link poStatementMsgstr  Statement
hi def link poStatementMsgidplural  Statement
hi def link poStatementMsgCTxt Statement
hi def link poPluralCaseN      Constant

hi def link poStringCTxt	    Comment
hi def link poStringID	    String
hi def link poStringSTR	    String
hi def link poCommentKDE       Comment
hi def link poCommentKDEError  Error
hi def link poPluralKDE        Comment
hi def link poPluralKDEError   Error
hi def link poHeaderItem       Identifier
hi def link poHeaderUndefined  Todo
hi def link poKDEdesktopFile   Identifier

hi def link poHtml              Identifier
hi def link poHtmlNot           String
hi def link poHtmlTranslatables String
hi def link poLineBreak         String

hi def link poFormat	    poSpecial
hi def link poSpecial	    Special
hi def link poAcceleratorId    Special
hi def link poAcceleratorStr   Special
hi def link poVariable         Special

hi def link poMsguniqError        Special
hi def link poMsguniqErrorMarkers Comment


let b:current_syntax = "po"

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:set ts=8 sts=2 sw=2 noet:
