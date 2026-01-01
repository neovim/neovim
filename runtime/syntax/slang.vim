" Vim syntax file
" Language:	S-Lang
" Maintainer:	Jan Hlavacek <lahvak@math.ohio-state.edu>
" Last Change:	980216

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn keyword slangStatement	break return continue EXECUTE_ERROR_BLOCK
syn match slangStatement	"\<X_USER_BLOCK[0-4]\>"
syn keyword slangLabel		case
syn keyword slangConditional	!if if else switch
syn keyword slangRepeat		while for _for loop do forever
syn keyword slangDefinition	define typedef variable struct
syn keyword slangOperator	or and andelse orelse shr shl xor not
syn keyword slangBlock		EXIT_BLOCK ERROR_BLOCK
syn match slangBlock		"\<USER_BLOCK[0-4]\>"
syn keyword slangConstant	NULL
syn keyword slangType		Integer_Type Double_Type Complex_Type String_Type Struct_Type Ref_Type Null_Type Array_Type DataType_Type

syn match slangOctal		"\<0\d\+\>" contains=slangOctalError
syn match slangOctalError	"[89]\+" contained
syn match slangHex		"\<0[xX][0-9A-Fa-f]*\>"
syn match slangDecimal		"\<[1-9]\d*\>"
syn match slangFloat		"\<\d\+\."
syn match slangFloat		"\<\d\+\.\d\+\([Ee][-+]\=\d\+\)\=\>"
syn match slangFloat		"\<\d\+\.[Ee][-+]\=\d\+\>"
syn match slangFloat		"\<\d\+[Ee][-+]\=\d\+\>"
syn match slangFloat		"\.\d\+\([Ee][-+]\=\d\+\)\=\>"
syn match slangImaginary	"\.\d\+\([Ee][-+]\=\d*\)\=[ij]\>"
syn match slangImaginary	"\<\d\+\(\.\d*\)\=\([Ee][-+]\=\d\+\)\=[ij]\>"

syn region slangString oneline start='"' end='"' skip='\\"'
syn match slangCharacter	"'[^\\]'"
syn match slangCharacter	"'\\.'"
syn match slangCharacter	"'\\[0-7]\{1,3}'"
syn match slangCharacter	"'\\d\d\{1,3}'"
syn match slangCharacter	"'\\x[0-7a-fA-F]\{1,2}'"

syn match slangDelim		"[][{};:,]"
syn match slangOperator		"[-%+/&*=<>|!~^@]"

"catch errors caused by wrong parenthesis
syn region slangParen	matchgroup=slangDelim transparent start='(' end=')' contains=ALLBUT,slangParenError
syn match slangParenError	")"

syn match slangComment		"%.*$"
syn keyword slangOperator	sizeof

syn region slangPreCondit start="^\s*#\s*\(ifdef\>\|ifndef\>\|iftrue\>\|ifnfalse\>\|iffalse\>\|ifntrue\>\|if\$\|ifn\$\|\|elif\>\|else\>\|endif\>\)" skip="\\$" end="$" contains=cComment,slangString,slangCharacter,slangNumber

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link slangDefinition	Type
hi def link slangBlock		slangDefinition
hi def link slangLabel		Label
hi def link slangConditional	Conditional
hi def link slangRepeat		Repeat
hi def link slangCharacter	Character
hi def link slangFloat		Float
hi def link slangImaginary	Float
hi def link slangDecimal		slangNumber
hi def link slangOctal		slangNumber
hi def link slangHex		slangNumber
hi def link slangNumber		Number
hi def link slangParenError	Error
hi def link slangOctalError	Error
hi def link slangOperator		Operator
hi def link slangStructure	Structure
hi def link slangInclude		Include
hi def link slangPreCondit	PreCondit
hi def link slangError		Error
hi def link slangStatement	Statement
hi def link slangType		Type
hi def link slangString		String
hi def link slangConstant		Constant
hi def link slangRangeArray	slangConstant
hi def link slangComment		Comment
hi def link slangSpecial		SpecialChar
hi def link slangTodo		Todo
hi def link slangDelim		Delimiter


let b:current_syntax = "slang"

" vim: ts=8
