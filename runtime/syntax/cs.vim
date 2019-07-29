" Vim syntax file
" Language:            C#
" Maintainer:          Nick Jensen <nickspoon@gmail.com>
" Former Maintainers:  Anduin Withers <awithers@anduin.com>
"                      Johannes Zellner <johannes@zellner.org>
" Last Change:         2018-11-26
" Filenames:           *.cs
" License:             Vim (see :h license)
" Repository:          https://github.com/nickspoons/vim-cs
"
" REFERENCES:
" [1] ECMA TC39: C# Language Specification (WD13Oct01.doc)

if exists('b:current_syntax')
  finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim


syn keyword	csType	bool byte char decimal double float int long object sbyte short string T uint ulong ushort var void dynamic
syn keyword	csStorage	delegate enum interface namespace struct
syn keyword	csRepeat	break continue do for foreach goto return while
syn keyword	csConditional	else if switch
syn keyword	csLabel	case default
syn match	csOperatorError	display +::+
syn match	csGlobal	display +global::+
" user labels (see [1] 8.6 Statements)
syn match	csLabel	display +^\s*\I\i*\s*:\([^:]\)\@=+
syn keyword	csModifier	abstract const extern internal override private protected public readonly sealed static virtual volatile
syn keyword	csConstant	false null true
syn keyword	csException	try catch finally throw when
syn keyword	csLinq	ascending by descending equals from group in into join let on orderby select where
syn keyword	csAsync	async await

syn keyword	csUnspecifiedStatement	as base checked event fixed in is lock nameof operator out params ref sizeof stackalloc this unchecked unsafe using
syn keyword	csUnsupportedStatement	add remove value
syn keyword	csUnspecifiedKeyword	explicit implicit

" Contextual Keywords
syn match	csContextualStatement	/\<yield[[:space:]\n]\+\(return\|break\)/me=s+5
syn match	csContextualStatement	/\<partial[[:space:]\n]\+\(class\|struct\|interface\)/me=s+7
syn match	csContextualStatement	/\<\(get\|set\)\(;\|[[:space:]\n]*{\)/me=s+3
syn match	csContextualStatement	/\<where\>[^:]\+:/me=s+5

" Operators
syn keyword	csTypeOf	typeof contained
syn region	csTypeOfStatement	start="typeof(" end=")" contains=csType, csTypeOf

" Punctuation
syn match	csBraces	"[{}\[\]]" display
syn match	csParens	"[()]" display
syn match	csOpSymbols	"[+\-=]\{1,2}" display
syn match	csOpSymbols	"[><]\{2}" display
syn match	csOpSymbols	"\s\zs[><]\ze\_s" display
syn match	csOpSymbols	"[!><+\-*/]=" display
syn match	csOpSymbols	"[!*/^]" display
syn match	csOpSymbols	"=>" display
syn match	csEndColon	";" display
syn match	csLogicSymbols	"&&" display
syn match	csLogicSymbols	"||" display
syn match	csLogicSymbols	"?" display
syn match	csLogicSymbols	":" display

" Comments
"
" PROVIDES: @csCommentHook
syn keyword	csTodo	contained TODO FIXME XXX NOTE HACK TBD
syn region	csComment	start="/\*"  end="\*/" contains=@csCommentHook,csTodo,@Spell
syn match	csComment	"//.*$" contains=@csCommentHook,csTodo,@Spell

" xml markup inside '///' comments
syn cluster	xmlRegionHook	add=csXmlCommentLeader
syn cluster	xmlCdataHook	add=csXmlCommentLeader
syn cluster	xmlStartTagHook	add=csXmlCommentLeader
syn keyword	csXmlTag	contained Libraries Packages Types Excluded ExcludedTypeName ExcludedLibraryName
syn keyword	csXmlTag	contained ExcludedBucketName TypeExcluded Type TypeKind TypeSignature AssemblyInfo
syn keyword	csXmlTag	contained AssemblyName AssemblyPublicKey AssemblyVersion AssemblyCulture Base
syn keyword	csXmlTag	contained BaseTypeName Interfaces Interface InterfaceName Attributes Attribute
syn keyword	csXmlTag	contained AttributeName Members Member MemberSignature MemberType MemberValue
syn keyword	csXmlTag	contained ReturnValue ReturnType Parameters Parameter MemberOfPackage
syn keyword	csXmlTag	contained ThreadingSafetyStatement Docs devdoc example overload remarks returns summary
syn keyword	csXmlTag	contained threadsafe value internalonly nodoc exception param permission platnote
syn keyword	csXmlTag	contained seealso b c i pre sub sup block code note paramref see subscript superscript
syn keyword	csXmlTag	contained list listheader item term description altcompliant altmember

syn cluster xmlTagHook add=csXmlTag

syn match	csXmlCommentLeader	+\/\/\/+    contained
syn match	csXmlComment	+\/\/\/.*$+ contains=csXmlCommentLeader,@csXml,@Spell
syn include	@csXml syntax/xml.vim
hi def link	xmlRegion Comment


" [1] 9.5 Pre-processing directives
syn region	csPreCondit	start="^\s*#\s*\(define\|undef\|if\|elif\|else\|endif\|line\|error\|warning\)" skip="\\$" end="$" contains=csComment keepend
syn region	csRegion	matchgroup=csPreCondit start="^\s*#\s*region.*$" end="^\s*#\s*endregion" transparent fold contains=TOP
syn region	csSummary	start="^\s*/// <summary" end="^\%\(\s*///\)\@!" transparent fold keepend


syn region	csClassType	start="@\@1<!\<class\>"hs=s+6 end="[:\n{]"me=e-1 contains=csClass
syn region	csNewType	start="@\@1<!\<new\>"hs=s+4 end="[;\n{(<\[]"me=e-1 contains=csNew contains=csNewType
syn region	csIsType	start=" is "hs=s+4 end="[A-Za-z0-9]\+" oneline contains=csIsAs
syn region	csIsType	start=" as "hs=s+4 end="[A-Za-z0-9]\+" oneline contains=csIsAs
syn keyword	csNew	new contained
syn keyword	csClass	class contained
syn keyword	csIsAs	is as

" Strings and constants
syn match	csSpecialError	"\\." contained
syn match	csSpecialCharError	"[^']" contained
" [1] 9.4.4.4 Character literals
syn match	csSpecialChar	+\\["\\'0abfnrtvx]+ contained display
syn match	csUnicodeNumber	+\\u\x\{4}+ contained contains=csUnicodeSpecifier display
syn match	csUnicodeNumber	+\\U\x\{8}+ contained contains=csUnicodeSpecifier display
syn match	csUnicodeSpecifier	+\\[uU]+ contained display

syn region	csString	matchgroup=csQuote start=+"+  end=+"+ end=+$+ extend contains=csSpecialChar,csSpecialError,csUnicodeNumber,@Spell
syn match	csCharacter	"'[^']*'" contains=csSpecialChar,csSpecialCharError display
syn match	csCharacter	"'\\''" contains=csSpecialChar display
syn match	csCharacter	"'[^\\]'" display
syn match	csNumber	"\<0[0-7]*[lL]\=\>" display
syn match	csNumber	"\<0[xX]\x\+[lL]\=\>" display
syn match	csNumber	"\<\d\+[lL]\=\>" display
syn match	csNumber	"\<\d\+\.\d*\%\([eE][-+]\=\d\+\)\=[fFdD]\=" display
syn match	csNumber	"\.\d\+\%\([eE][-+]\=\d\+\)\=[fFdD]\=" display
syn match	csNumber	"\<\d\+[eE][-+]\=\d\+[fFdD]\=\>" display
syn match	csNumber	"\<\d\+\%\([eE][-+]\=\d\+\)\=[fFdD]\>" display

syn region	csInterpolatedString	matchgroup=csQuote start=+\$"+ end=+"+ end=+$+ extend contains=csInterpolation,csEscapedInterpolation,csSpecialChar,csSpecialError,csUnicodeNumber,@Spell

syn region	csInterpolation	matchgroup=csInterpolationDelimiter start=+{+ end=+}+ keepend contained contains=@csAll,csBracketed,csInterpolationAlign,csInterpolationFormat
syn match	csEscapedInterpolation	"{{" transparent contains=NONE display
syn match	csEscapedInterpolation	"}}" transparent contains=NONE display
syn region	csInterpolationAlign	matchgroup=csInterpolationAlignDel start=+,+ end=+}+ end=+:+me=e-1 contained contains=csNumber,csConstant,csCharacter,csParens,csOpSymbols,csString,csBracketed display
syn match	csInterpolationFormat	+:[^}]\+}+ contained contains=csInterpolationFormatDel display
syn match	csInterpolationAlignDel	+,+ contained display
syn match	csInterpolationFormatDel	+:+ contained display

syn region	csVerbatimString	matchgroup=csQuote start=+@"+ end=+"+ skip=+""+ extend contains=csVerbatimQuote,@Spell
syn match	csVerbatimQuote	+""+ contained
syn match	csQuoteError	+@$"+he=s+2,me=s+2

syn region	csInterVerbString	matchgroup=csQuote start=+\$@"+ end=+"+ skip=+""+ extend contains=csInterpolation,csEscapedInterpolation,csSpecialChar,csSpecialError,csUnicodeNumber,csVerbatimQuote,@Spell

syn region	csBracketed	matchgroup=csParens start=+(+ end=+)+ contained transparent contains=@csAll,csBracketed

syn cluster	csAll	contains=csCharacter,csClassType,csComment,csContextualStatement,csEndColon,csInterpolatedString,csIsType,csLabel,csLogicSymbols,csNewType,csConstant,csNumber,csOpSymbols,csOperatorError,csParens,csPreCondit,csRegion,csString,csSummary,csUnicodeNumber,csUnicodeSpecifier,csVerbatimString

" The default highlighting.
hi def link	csType	Type
hi def link	csClassType	Type
hi def link	csIsType	Type
hi def link	csStorage	Structure
hi def link	csClass	Structure
hi def link	csRepeat	Repeat
hi def link	csConditional	Conditional
hi def link	csLabel	Label
hi def link	csModifier	StorageClass
hi def link	csConstant	Constant
hi def link	csException	Exception
hi def link	csTypeOf	Operator
hi def link	csTypeOfStatement	Typedef
hi def link	csUnspecifiedStatement	Statement
hi def link	csUnsupportedStatement	Statement
hi def link	csUnspecifiedKeyword	Keyword
hi def link	csNew	Statement
hi def link	csLinq	Statement
hi def link	csIsAs 	Keyword
hi def link	csAsync	Keyword
hi def link	csContextualStatement	Statement
hi def link	csOperatorError	Error

hi def link	csTodo	Todo
hi def link	csComment	Comment

hi def link	csOpSymbols	Operator
hi def link	csLogicSymbols	Operator

hi def link	csSpecialError	Error
hi def link	csSpecialCharError	Error
hi def link	csString	String
hi def link	csQuote	String
hi def link	csQuoteError	Error
hi def link	csInterpolatedString	String
hi def link	csVerbatimString	String
hi def link	csInterVerbString	String
hi def link	csVerbatimQuote	SpecialChar
hi def link	csPreCondit	PreCondit
hi def link	csCharacter	Character
hi def link	csSpecialChar	SpecialChar
hi def link	csNumber	Number
hi def link	csUnicodeNumber	SpecialChar
hi def link	csUnicodeSpecifier	SpecialChar
hi def link	csInterpolationDelimiter	Delimiter
hi def link	csInterpolationAlignDel	csInterpolationDelimiter
hi def link	csInterpolationFormat	csInterpolationDelimiter
hi def link	csInterpolationFormatDel	csInterpolationDelimiter

" xml markup
hi def link	csXmlCommentLeader	Comment
hi def link	csXmlComment	Comment
hi def link	csXmlTag	Statement

let b:current_syntax = 'cs'

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: vts=16,28
