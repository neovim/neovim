" Vim syntax file
" Language:		Pkl
" Maintainer:		Jan Claußen <jan DOT claussen10 AT web DOT de>
" Last Change:		2026 Oct 20

if exists("b:current_syntax")
  finish
endif

" We use line-continuation here
let s:cpo_save = &cpo
set cpo&vim

" Needed to properly highlight multiline strings
syn sync fromstart

" PKL supports non-Unicode identifiers. So we modify the keyword character
" class to include them
syn iskeyword @,48-57,192-255,$,_

" Declare a variable for identifiers
let s:id  = '\%(\K\+\d*[_$]*\K*\d*[_$]*\)'

" --- Shebang ---
syn match	pklShebang	"\%^#!.*"

" --- Operators ---
" Defined before comments and strings, so these win where both start at the
" same position, e.g. '//' over '/'
syn match	pklPunctuation	"[,.]\|?\."
syn match	pklOperator	"[-+*/%<>=!?|&~]"
syn match	pklOperator	"??\|!!\|\*\*\|\~/\|&&\|||\||>\|->\|[=!<>]=\|\.\.\.?\="

" --- Annotations ---
" @Deprecated, @ModuleInfo { minPklVersion = "0.25.0" }, @foo.Bar
exe $'syn match	pklDecorator     "@{s:id}\%(\.{s:id}\)*"'

" --- Comments ---
syn match	pklComment	"\/\{2}.*"
syn match	pklDocComment	"\/\{3}.*"
syn region	pklMultiComment	start="\/\*" end="\*\/" keepend fold

" --- Strings ---
syn region	pklString	start=+"+ end=+"+ contains=pklEscape,pklUnicodeEscape,pklStringInterpolation oneline
syn region	pklMultiString	start=+"""+ skip=+\\."+ end=+"""+ contains=pklEscape,pklUnicodeEscape keepend fold
syn match	pklEscape	"\\[\\tnr"]" contained containedin=pklString,pklMultiString
syn match	pklEscape	"\\$" contained containedin=pklMultiString
syn match	pklUnicode	"[0-9A-Fa-f]\+" contained

" --- String interpolation ---
syn cluster	pklExpr	contains=pklNumber,pklFloat,pklOperator,pklPunctuation,pklIdentifier,pklIdentifierExplicit,pklTypeName,pklTypeDecl,pklFunction,pklParen,pklBracket,pklBlock,pklString,pklMultiString,pklBoolean,pklClass,pklConditional,pklConstant,pklException,pklInclude,pklKeyword,pklStatement,pklSpecial
" Standard interpolation
syn region	pklStringInterpolation matchgroup=pklDelimiter
	  \ start=+\\(+ end=+)+ contains=@pklExpr
	  \ contained containedin=pklString,pklMultiString oneline
" Unicode escape sequences
syn region	pklUnicodeEscape matchgroup=pklDelimiter
	  \ start=+\\u{+ end=+}+ contains=pklUnicode
	  \ contained containedin=pklString,pklMultiString

" --- Basic data types ---
syn keyword	pklType
	  \ UInt UInt8 UInt16 UInt32 UInt64 UInt128
	  \ Int Int8 Int16 Int32 Int64 Int128
	  \ Float
	  \ Number
	  \ String
	  \ Boolean
	  \ Null
	  \ Any

syn keyword	pklCollections
	  \ Map Mapping
	  \ List Listing
	  \ Set

" --- Custom string delimiters ---
function! s:DefineCustomStringDelimiters(n)
  for x in range(1, a:n)
    exe $'syn region pklString{x}Pound start=+{repeat("#", x)}"+ end=+"{repeat("#", x)}+ contains=pklStringInterpolation{x}Pound,pklEscape{x}Pound oneline'
    exe $'hi def link pklString{x}Pound String'

    exe $'syn region pklMultiString{x}Pound start=+{repeat("#", x)}"""+ end=+"""{repeat("#", x)}+ contains=pklStringInterpolation{x}Pound,pklEscape{x}Pound keepend fold'
    exe $'hi def link pklMultiString{x}Pound String'

    exe $'syn match pklEscape{x}Pound "\\{repeat("#", x)}\%([\\tnr"]\|$\)" contained containedin=pklString{x}Pound,pklMultiString{x}Pound'
    exe $'hi def link pklEscape{x}Pound SpecialChar'

    exe $'syn region pklStringInterpolation{x}Pound matchgroup=pklDelimiter start=+\\{repeat("#", x)}(+ end=+)+ contains=@pklExpr contained containedin=pklString{x}Pound,pklMultiString{x}Pound oneline'

    exe $'syn region pklUnicodeEscape{x}Pound matchgroup=pklDelimiter start=+\\{repeat("#", x)}u{{+ end=+}}+ contains=pklUnicode contained containedin=pklString{x}Pound,pklMultiString{x}Pound'
    exe $'hi def link pklUnicodeEscape{x}Pound SpecialChar'
  endfor
endfunction

call s:DefineCustomStringDelimiters(6)

" --- Keywords ---
syn keyword	pklBoolean       false true
syn keyword	pklClass         outer super this module new
syn keyword	pklConditional   if else when
syn keyword	pklConstant      null NaN Infinity
syn keyword	pklException     throw
syn keyword	pklInclude       amends import extends as
syn keyword	pklKeyword       function let out is
syn keyword	pklModifier      abstract const external fixed hidden local open
syn keyword	pklReserved      case delete override protected record switch vararg
syn keyword	pklRepeat        for in
syn keyword	pklSpecial       nothing unknown
syn keyword	pklStatement     trace read
syn keyword	pklStruct        typealias class

" Include all unicode letters
exe $'syn match pklIdentifier "{s:id}"'

" Declared properties: foo = 1, foo: Int, foo { ... }, local foo = 1
" Declared after a modifier (local foo = 1) or in one-line objects
" (new { foo = 1 })
syn match	pklProperty	"^\s*\zs\l\k*\ze\s*\%(:\|=[=]\@!\|{\)"
syn match	pklProperty	"\%(\%(\<\%(abstract\|const\|external\|fixed\|hidden\|local\|open\)\s\+\|{\s*\)\)\@20<=\l\k*\ze\s*\%(:\|=[=]\@!\|{\)"

" Explicitely make keywords identifiers with backticks
syn region	pklIdentifierExplicit	start=+`+ end=+`+

" --- Numbers ---
" Digits can be separated by '_', e.g. 1_000_000 or 0xFF_FF
syn match	pklNumber	display "\<\d\+\%(_\d\+\)*\>"
syn match	pklNumber	display "\<0x\x\+\%(_\x\+\)*\>"
syn match	pklNumber	display "\<0b[01]\+\%(_[01]\+\)*\>"
syn match	pklNumber	display "\<0o[0-7]\+\%(_[0-7]\+\)*\>"
" floating point number, with dot, optional exponent
syn match	pklFloat	display "\<\d\+\%(_\d\+\)*\.\d\+\%(_\d\+\)*\%([eE][-+]\=\d\+\%(_\d\+\)*\)\=\>"
" floating point number, starting with a dot, optional exponent
syn match	pklFloat	display "\%(\k\|)\)\@1<!\.\d\+\%(_\d\+\)*\%([eE][-+]\=\d\+\%(_\d\+\)*\)\=\>"
" floating point number, without dot, with exponent
syn match	pklFloat	display "\<\d\+\%(_\d\+\)*[eE][-+]\=\d\+\%(_\d\+\)*\>"

" --- Brackets, operators, functions ---
syn region	pklParen	matchgroup=pklBrackets start='(' end=')' contains=ALLBUT,pklUnicode,pklTypeGroup transparent
syn region	pklBracket	matchgroup=pklBrackets start='\[' end=']' contains=ALLBUT,pklUnicode,pklTypeGroup transparent
syn region	pklBlock	matchgroup=pklBrackets start="{" end="}" contains=ALLBUT,pklUnicode,pklTypeGroup fold transparent

" --- Types ---
" Everything that can appear inside a type expression
syn cluster	pklTypeContents	contains=pklTypeArgs,pklTypeGroup,pklTypeName,pklType,pklCollections,pklIdentifier,pklIdentifierExplicit,pklOperator,pklPunctuation,pklParen,pklString,pklNumber,pklFloat,pklConstant,pklSpecial,pklBoolean,pklClass,pklRepeat,pklKeyword,pklComment,pklMultiComment

" Type annotations: foo: Listing<Bar>?, function f(a: Int): String
" Pkl only uses ':' for type annotations, so the type runs from the ':' up to
" the next '=', ',', ')', '{', '}' or the end of the line. Contained regions
" (type arguments, parens) consume these characters while they are open, so
" Mapping<String, Int> or String(length == 3) don't end the annotation early.
syn region	pklTypeAnnot	matchgroup=pklPunctuation start=':'
	  \ end='\%(\s*[=,){}]\)\@=\|$'
	  \ contains=@pklTypeContents
	  \ transparent

" Type arguments: Listing<Mapping<String, Listing<Int>>>. The region contains
" itself, so every '<' opens a new level and every '>' closes exactly one. To
" not confuse it with the comparison operator, the '<' must directly follow a
" capitalized type name or the name in a generic method declaration
" (function map<R>). '->' inside function types is consumed by pklOperator
" before it can end the region, '>' inside constraints like
" String(length > 3) by pklParen.
syn region	pklTypeArgs	matchgroup=pklBrackets
	  \ start='\%(\<\u\k*\|\<function\s\+\k\+\)\@<=<' end='>'
	  \ contains=@pklTypeContents
	  \ transparent

" Grouping parens inside types: (*LogicStatement|Boolean)?, (Int) -> String.
" A paren directly after a type (a name, '>', '?' or ')') is a constraint like
" String(!isEmpty) or Listing<Int>(!isEmpty) and is left to pklParen, since it
" holds an expression. '->' is excluded so (Int) -> (String) still works.
" Defined after pklParen so it wins at the same position.
syn region	pklTypeGroup	matchgroup=pklBrackets
	  \ start='\%(\%(\k\|[^-]>\|[?)]\)\s*\)\@<!(' end=')'
	  \ contains=@pklTypeContents
	  \ contained transparent

" Like the official tree-sitter queries, every capitalized identifier is a
" type: Listing<HttpSdConfig>, Foo.bar(), new Baz {}. Defined after
" pklIdentifier so it wins at the same position.
syn match	pklTypeName	"\<\u\k*"

" Declared and referenced classes: class Foo, typealias Foo, extends Foo,
" new Foo {}, x is Foo, x as Foo. Qualified names like new k8s.Pod {} are
" allowed after the keywords that only take types.
" The lookbehinds are bounded, unbounded ones make highlighting twice as slow.
" \zs doesn't work here, as the keyword in front wins over the match.
syn match	pklTypeDecl	"\%(\<\%(class\|typealias\)\s\+\)\@20<=\k\+"
syn match	pklTypeDecl	"\%(\<\%(new\|extends\|is\|as\)\s\+\)\@20<=\%(\k\+\.\)*\u\k*"

" The right-hand side of a typealias is a type. It may continue on the next
" lines as long as these start with '|', e.g.
"   typealias Weekday =
"     "MO"
"     |"TU"
syn region	pklTypeAlias	start='\%(\<typealias\s\+\k\+\%(<[^>]*>\)\=\s*\)\@<=='
	  \ end='\%(=\s*\)\@<!\ze\%(\n\%(\s*\%(|\|\/\/\|$\)\)\@!\|\%$\)'
	  \ contains=@pklTypeContents
	  \ transparent

exe $'syn match	pklFunction	"\<\h{s:id}*\>\ze\_s*[?|\*]\?(" contains=pklType'
" Method declarations, also generic ones like function map<R>(...)
syn match	pklFunction	"\%(\<function\s\+\)\@20<=\k\+"

" --- Highlight links ---
hi def link	pklBoolean                       Boolean
hi def link	pklBrackets                      Delimiter
hi def link	pklClass                         Statement
hi def link	pklCollections                   Type
hi def link	pklComment                       Comment
hi def link	pklConditional                   Conditional
hi def link	pklConstant                      Constant
hi def link	pklDecorator                     Special
hi def link	pklDelimiter                     Delimiter
hi def link	pklDocComment                    Comment
hi def link	pklEscape                        SpecialChar
hi def link	pklException                     Exception
hi def link	pklFloat                         Number
hi def link	pklFunction                      Function
hi def link	pklInclude                       Include
hi def link	pklKeyword                       Keyword
hi def link	pklModifier                      StorageClass
hi def link	pklMultiComment                  Comment
hi def link	pklMultiString                   String
hi def link	pklOperator                      Operator
hi def link	pklProperty                      Identifier
hi def link	pklPunctuation                   Delimiter
hi def link	pklNumber                        Number
hi def link	pklRepeat                        Repeat
hi def link	pklReserved                      Error
hi def link	pklShebang                       Comment
hi def link	pklSpecial                       Special
hi def link	pklStatement                     Statement
hi def link	pklString                        String
hi def link	pklStruct                        Structure
hi def link	pklType                          Type
hi def link	pklTypeName                      Type
hi def link	pklTypeDecl                      Type
hi def link	pklUnicodeEscape                 SpecialChar

let b:current_syntax = "pkl"

let &cpo = s:cpo_save
unlet s:cpo_save
