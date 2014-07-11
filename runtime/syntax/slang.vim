" Vim syntax file
" Language:	S-Lang
" Maintainer:	Jan Hlavacek <lahvak@math.ohio-state.edu>
" Last Change:	980216

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_slang_syntax_inits")
  if version < 508
    let did_slang_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink slangDefinition	Type
  HiLink slangBlock		slangDefinition
  HiLink slangLabel		Label
  HiLink slangConditional	Conditional
  HiLink slangRepeat		Repeat
  HiLink slangCharacter	Character
  HiLink slangFloat		Float
  HiLink slangImaginary	Float
  HiLink slangDecimal		slangNumber
  HiLink slangOctal		slangNumber
  HiLink slangHex		slangNumber
  HiLink slangNumber		Number
  HiLink slangParenError	Error
  HiLink slangOctalError	Error
  HiLink slangOperator		Operator
  HiLink slangStructure	Structure
  HiLink slangInclude		Include
  HiLink slangPreCondit	PreCondit
  HiLink slangError		Error
  HiLink slangStatement	Statement
  HiLink slangType		Type
  HiLink slangString		String
  HiLink slangConstant		Constant
  HiLink slangRangeArray	slangConstant
  HiLink slangComment		Comment
  HiLink slangSpecial		SpecialChar
  HiLink slangTodo		Todo
  HiLink slangDelim		Delimiter

  delcommand HiLink
endif

let b:current_syntax = "slang"

" vim: ts=8
