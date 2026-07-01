" Vim syntax file
" Language: XML
" Maintainer: Christian Brabandt <cb@256bit.org>
" Repository: https://github.com/chrisbra/vim-xml-ftplugin
" Previous Maintainer: Johannes Zellner <johannes@zellner.org>
" Author: Paul Siegmann <pauls@euronet.nl>
" Last Changed:	30 Jun 2026
" Filenames:	*.xml
" Last Change:
" 20190923 - Fix xmlEndTag to match xmlTag (vim/vim#884)
" 20190924 - Fix xmlAttribute property (amadeus/vim-xml@d8ce1c946)
" 20191103 - Enable spell checking globally
" 20210428 - Improve syntax synchronizing
" 20260630 - Improve performance

" CONFIGURATION:
"   syntax folding can be turned on by
"
"      let g:xml_syntax_folding = 1
"
"   before the syntax file gets loaded (e.g. in ~/.vimrc).
"   This might slow down syntax highlighting significantly,
"   especially for large files.
"
" CREDITS:
"   The original version was derived by Paul Siegmann from
"   Claudio Fleiner's html.vim.
"
" REFERENCES:
"   [1] http://www.w3.org/TR/2000/REC-xml-20001006
"   [2] http://www.w3.org/XML/1998/06/xmlspec-report-19980910.htm
"
"   as <hirauchi@kiwi.ne.jp> pointed out according to reference [1]
"
"   2.3 Common Syntactic Constructs
"   [4]    NameChar    ::=    Letter | Digit | '.' | '-' | '_' | ':' | CombiningChar | Extender
"   [5]    Name        ::=    (Letter | '_' | ':') (NameChar)*
"
" NOTE:
"   1) empty tag delimiters "/>" inside attribute values (strings)
"      confuse syntax highlighting.
"   2) for large files, folding can be pretty slow, especially when
"      loading a file the first time and viewoptions contains 'folds'
"      so that folds of previous sessions are applied.
"      Don't use 'foldmethod=syntax' in this case.


" Quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

let s:xml_cpo_save = &cpo
set cpo&vim

syn case match

" Allow spell checking in tag values,
" there is no syntax region for that,
" so enable spell checking in top-level elements
" <tag>This text is spell checked</tag>
syn spell toplevel

" mark illegal characters
syn match xmlError "<"
syn match xmlError "&"

" strings (inside tags) aka VALUES
"
" EXAMPLE:
"
" <tag foo.attribute = "value">
"                      ^^^^^^^
syn region  xmlString contained start=+"+ end=+"+ contains=xmlEntity,@Spell display
syn region  xmlString contained start=+'+ end=+'+ contains=xmlEntity,@Spell display


" punctuation (within attributes) e.g. <tag xml:foo.attribute ...>
"                                              ^   ^
" syn match   xmlAttribPunct +[-:._]+ contained display
syn match   xmlAttribPunct +[:.]+ contained display

" no highlighting for xmlEqual (xmlEqual has no highlighting group)
syn match   xmlEqual +=+ display


" attribute, everything before the '='
"
" PROVIDES: @xmlAttribHook
"
" EXAMPLE:
"
" <tag foo.attribute = "value">
"      ^^^^^^^^^^^^^
"
syn match   xmlAttrib
    \ +\%#=1[-/!?<>"']\@1<!\<[a-zA-Z:_][-.0-9a-zA-Z:_]*\>['"]\@!+
    \ contained
    \ contains=xmlAttribPunct,@xmlAttribHook
    \ display


if exists("g:xml_namespace_transparent")
    command! -nargs=+ XmlTransparent <args> transparent
else
    command! -nargs=+ XmlTransparent <args>
endif

" namespace spec
"
" PROVIDES: @xmlNamespaceHook
"
" EXAMPLE:
"
" <xsl:for-each select = "lola">
"  ^^^
"
XmlTransparent syn match   xmlNamespace
    \ +<[^ /!?<>"':]\+\ze:+lc=1
    \ contained
    \ contains=@xmlNamespaceHook
    \ display
XmlTransparent syn match   xmlNamespace
    \ +</[^ /!?<>"':]\+\ze:+lc=2
    \ contained
    \ contains=@xmlNamespaceHook
    \ display

delcommand XmlTransparent


" tag name
"
" PROVIDES: @xmlTagHook
"
" EXAMPLE:
"
" <tag foo.attribute = "value">
"  ^^^
"
syn match   xmlTagName
    \ +<[^ /!?<>"']\++lc=1
    \ contained
    \ contains=xmlNamespace,xmlAttribPunct,@xmlTagHook
    \ display
syn match   xmlTagName
    \ +</[^ /!?<>"']\++lc=2
    \ contained
    \ contains=xmlNamespace,xmlAttribPunct,@xmlTagHook
    \ display


if exists('g:xml_syntax_folding')
    command! -nargs=+ XmlContained <args> contained
    command! -nargs=+ XmlFold <args> fold
else
    command! -nargs=+ XmlContained <args>
    command! -nargs=+ XmlFold <args>
endif

" start tag
" use matchgroup=xmlTag to skip over the leading '<'
"
" PROVIDES: @xmlStartTagHook
"
" EXAMPLE:
"
" <tag id="whoops">
" s^^^^^^^^^^^^^^^e
"
XmlContained syn region   xmlTag
	\ matchgroup=xmlTag start=+<\ze[^ /!?<>"']+
	\ matchgroup=xmlTag end=+>+
	\ contains=xmlError,xmlTagName,xmlAttrib,xmlEqual,xmlString,@xmlStartTagHook


" highlight the end tag
"
" PROVIDES: @xmlTagHook
" (should we provide a separate @xmlEndTagHook ?)
"
" EXAMPLE:
"
" </tag>
" ^^^^^^
"
XmlContained syn region   xmlEndTag
	\ matchgroup=xmlTag start=+</\ze[^ /!?<>"']+
	\ matchgroup=xmlTag end=+>+
	\ contains=xmlTagName,xmlNamespace,xmlAttribPunct,@xmlTagHook

delcommand XmlContained


if exists('g:xml_syntax_folding')
    " tag elements with syntax-folding.
    " NOTE: NO HIGHLIGHTING -- highlighting is done by contained elements
    "
    " PROVIDES: @xmlRegionHook
    "
    " EXAMPLE:
    "
    " <tag id="whoops">
    "   <!-- comment -->
    "   <another.tag></another.tag>
    "   <empty.tag/>
    "   some data
    " </tag>
    "
    syn region   xmlRegion
	\ start=+<\z([^ /!?<>"']\+\)+
	\ skip=+<!--\_.\{-}-->+
	\ end=+</\z1\_\s\{-}>+
	\ end=+/>+
	\ fold
	\ contains=xmlTag,xmlEndTag,xmlCdata,xmlRegion,xmlComment,xmlEntity,xmlProcessing,@xmlRegionHook,@Spell
	\ keepend
	\ extend
endif


" &entities; compare with dtd
syn match   xmlEntity                 "&[^; \t]*;" contains=xmlEntityPunct
syn match   xmlEntityPunct  contained "[&.;]"

" The real comments (this implements the comments as defined by xml,
" but not all xml pages actually conform to it. Errors are flagged.
XmlFold syn region  xmlComment
	\ start=+<!+
	\ end=+>+
	\ contains=xmlCommentStart,xmlCommentError
	\ extend

syn match xmlCommentStart   contained "<!" nextgroup=xmlCommentPart
syn keyword xmlTodo         contained TODO FIXME XXX
syn match   xmlCommentError contained "[^><!]"
syn region  xmlCommentPart
    \ start=+--+
    \ end=+--+
    \ contained
    \ contains=xmlTodo,@xmlCommentHook,@Spell


" CData sections
"
" PROVIDES: @xmlCdataHook
"
syn region    xmlCdata
    \ start=+<!\[CDATA\[+
    \ end=+]]>+
    \ contains=xmlCdataStart,xmlCdataEnd,@xmlCdataHook,@Spell
    \ keepend
    \ extend

" using the following line instead leads to corrupt folding at CDATA regions
" syn match    xmlCdata      +<!\[CDATA\[\_.\{-}]]>+  contains=xmlCdataStart,xmlCdataEnd,@xmlCdataHook
syn match    xmlCdataStart +<!\[CDATA\[+  contained contains=xmlCdataCdata
syn keyword  xmlCdataCdata CDATA          contained
syn match    xmlCdataEnd   +]]>+          contained


" Processing instructions
" This allows "?>" inside strings -- good idea?
syn region  xmlProcessing matchgroup=xmlProcessingDelim start="<?" end="?>" contains=xmlAttrib,xmlEqual,xmlString


" DTD -- we use dtd.vim here
XmlFold syn region  xmlDocType matchgroup=xmlDocTypeDecl
	\ start="<!DOCTYPE"he=s+2,rs=s+2 end=">"
	\ contains=xmlDocTypeKeyword,xmlInlineDTD,xmlString

delcommand XmlFold

syn keyword xmlDocTypeKeyword contained DOCTYPE PUBLIC SYSTEM
syn region  xmlInlineDTD contained matchgroup=xmlDocTypeDecl start="\[" end="]" contains=@xmlDTD
syn include @xmlDTD <sfile>:p:h/dtd.vim
unlet b:current_syntax


" synchronizing

syn sync match xmlSyncComment grouphere xmlComment +<!--+
syn sync match xmlSyncComment groupthere NONE +-->+

" The following is slow on large documents (and the doctype is optional
" syn sync match xmlSyncDT grouphere  xmlDocType +\_.\(<!DOCTYPE\)\@=+
" syn sync match xmlSyncDT groupthere  NONE       +]>+

if exists('g:xml_syntax_folding')
    syn sync match xmlSync grouphere   xmlRegion  +\_.\(<[^ /!?<>"']\+\)\@=+
    " syn sync match xmlSync grouphere  xmlRegion "<[^ /!?<>"']*>"
    syn sync match xmlSync groupthere  xmlRegion  +</[^ /!?<>"']\+>+
endif

syn sync minlines=100 maxlines=200


" The default highlighting.
hi def link xmlTodo		Todo
hi def link xmlTag		Function
hi def link xmlTagName		Function
hi def link xmlEndTag		Identifier
if !exists("g:xml_namespace_transparent")
    hi def link xmlNamespace	Tag
endif
hi def link xmlEntity		Statement
hi def link xmlEntityPunct	Type

hi def link xmlAttribPunct	Comment
hi def link xmlAttrib		Type

hi def link xmlString		String
hi def link xmlComment		Comment
hi def link xmlCommentStart	xmlComment
hi def link xmlCommentPart	Comment
hi def link xmlCommentError	Error
hi def link xmlError		Error

hi def link xmlProcessingDelim	Comment
hi def link xmlProcessing	Type

hi def link xmlCdata		String
hi def link xmlCdataCdata	Statement
hi def link xmlCdataStart	Type
hi def link xmlCdataEnd		Type

hi def link xmlDocTypeDecl	Function
hi def link xmlDocTypeKeyword	Statement
hi def link xmlInlineDTD	Function

let b:current_syntax = "xml"

let &cpo = s:xml_cpo_save
unlet s:xml_cpo_save

" vim: ts=4
