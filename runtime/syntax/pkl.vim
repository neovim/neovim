" Vim syntax file
" Language:		PKL
" Maintainer:		Jan Claußen <jan DOT claussen10 AT web DOT de>
" Last Change:		2025 Sep 24

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

" --- Decorator ---
exe $'syn match	pklDecorator     "@{s:id}\{{1,}}"'

" --- Comments ---
syn match	pklComment	"\/\{2}.*"
syn match	pklDocComment	"\/\{3}.*"
syn region	pklMultiComment	start="\/\*" end="\*\/" keepend fold

" --- Strings ---
syn region	pklString	start=+"+ end=+"+ contains=pklEscape,pklUnicodeEscape,pklStringInterpolation oneline
syn region	pklMultiString	start=+"""+ skip=+\\."+ end=+"""+ contains=pklEscape,pklUnicodeEscape keepend fold
syn match	pklEscape	"\\[\\nt0rbaeuf"']" contained containedin=pklString,pklMultiString
syn match	pklUnicode	"[0-9A-Fa-f]\+" contained

" --- String interpolation ---
" Standard interpolation
syn region	pklStringInterpolation matchgroup=pklDelimiter
	  \ start=+\\(+ end=+)+ contains=pklNumbers,pklOperator,pklIdentifier,pklFunction,pklParen,pklString
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

    exe $'syn match pklEscape{x}Pound "\\{repeat("#", x) }[\\nt0rbaeuf"'']" contained containedin=pklString{x}Pound,pklMultiString{x}Pound'
    exe $'hi def link pklEscape{x}Pound SpecialChar'

    exe $'syn region pklStringInterpolation{x}Pound matchgroup=pklDelimiter start=+\\{repeat("#", x)}(+ end=+)+ contains=pklNumbers,pklOperator,pklIdentifier,pklFunction,pklParen,pklString contained containedin=pklString{x}Pound,pklMultiString{x}Pound oneline'

    exe $'syn region pklUnicodeEscape{x}Pound matchgroup=pklDelimiter start=+\\{repeat("#", x)}u{{+ end=+}}+ contains=pklUnicode contained containedin=pklString{x}Pound,pklMultiString{x}Pound'
    exe $'hi def link pklUnicodeEscape{x}Pound SpecialChar'
  endfor
endfunction

call s:DefineCustomStringDelimiters(5)

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

" Explicitely make keywords identifiers with backticks
syn region	pklIdentifierExplicit	start=+`+ end=+`+

syn match	pklOperator      ",\||\|+\|*\|->\|?\|-\|==\|=\|!=\|!" contained containedin=pklType

" --- Numbers ---
" decimal numbers
syn match	pklNumbers	display transparent "\<\d\|\.\d" contains=pklNumber,pklFloat,pklOctal
syn match	pklNumber	display contained "\d\%(\d\+\)*\>"
" hex numbers
syn match	pklNumber	display contained "0x\x\%('\=\x\+\)\>"
" binary numbers
syn match	pklNumber	display contained "0b[01]\%('\=[01]\+\)\>"
" octal numbers
syn match	pklOctal	display contained "0o\o\+\>"

"floating point number, with dot, optional exponent
syn match	pklFloat	display contained "\d\+\.\d\+\%(e[-+]\=\d\+\)\="
"floating point number, starting with a dot, optional exponent
syn match	pklFloat	display contained "\.\d\+\%(e[-+]\=\d\+\)\=\>"
"floating point number, without dot, with exponent
syn match	pklFloat	display contained "\d\+e[-+]\=\d\+\>"

" --- Brackets, operators, functions ---
syn region	pklParen	matchgroup=pklBrackets start='(' end=')' contains=ALLBUT,pklUnicode transparent
syn region	pklBracket	matchgroup=pklBrackets start='\[\|<::\@!' end=']\|:>' contains=ALLBUT,pklUnicode transparent
syn region	pklBlock	matchgroup=pklBrackets start="{" end="}" contains=ALLBUT,pklUnicode fold transparent

exe $'syn match	pklFunction	"\<\h{s:id}*\>\ze\_s*[?|\*]\?(" contains=pklType'

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
hi def link	pklNumber                        Number
hi def link	pklNumbers                       Number
hi def link	pklOctal                         Number
hi def link	pklRepeat                        Repeat
hi def link	pklReserved                      Error
hi def link	pklShebang                       Comment
hi def link	pklSpecial                       Special
hi def link	pklStatement                     Statement
hi def link	pklString                        String
hi def link	pklStruct                        Structure
hi def link	pklType                          Type
hi def link	pklUnicodeEscape                 SpecialChar

let b:current_syntax = "pkl"

let &cpo = s:cpo_save
unlet s:cpo_save
