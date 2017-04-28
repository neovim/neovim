" Vim syntax file
" Language:	Slice (ZeroC's Specification Language for Ice)
" Maintainer:	Morel Bodin <slice06@nym.hush.com>
" Last Change:	2005 Dec 03

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" The Slice keywords

syn keyword sliceType	    bool byte double float int long short string void
syn keyword sliceQualifier  const extends idempotent implements local nonmutating out throws
syn keyword sliceConstruct  class enum exception dictionary interface module LocalObject Object sequence struct
syn keyword sliceQualifier  const extends idempotent implements local nonmutating out throws
syn keyword sliceBoolean    false true

" Include directives
syn region  sliceIncluded    display contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match   sliceIncluded   display contained "<[^>]*>"
syn match   sliceInclude    display "^\s*#\s*include\>\s*["<]" contains=sliceIncluded

" Double-include guards
syn region  sliceGuard      start="^#\(define\|ifndef\|endif\)" end="$"

" Strings and characters
syn region sliceString		start=+"+  end=+"+

" Numbers (shamelessly ripped from c.vim, only slightly modified)
"integer number, or floating point number without a dot and with "f".
syn case ignore
syn match   sliceNumbers    display transparent "\<\d\|\.\d" contains=sliceNumber,sliceFloat,sliceOctal
syn match   sliceNumber     display contained "\d\+"
"hex number
syn match   sliceNumber     display contained "0x\x\+\(u\=l\{0,2}\|ll\=u\)\>"
" Flag the first zero of an octal number as something special
syn match   sliceOctal      display contained "0\o\+\(u\=l\{0,2}\|ll\=u\)\>" contains=sliceOctalZero
syn match   sliceOctalZero  display contained "\<0"
syn match   sliceFloat      display contained "\d\+f"
"floating point number, with dot, optional exponent
syn match   sliceFloat      display contained "\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\="
"floating point number, starting with a dot, optional exponent
syn match   sliceFloat      display contained "\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, without dot, with exponent
syn match   sliceFloat      display contained "\d\+e[-+]\=\d\+[fl]\=\>"
" flag an octal number with wrong digits
syn case match


" Comments
syn region sliceComment    start="/\*"  end="\*/"
syn match sliceComment	"//.*"

syn sync ccomment sliceComment

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link sliceComment	Comment
hi def link sliceConstruct	Keyword
hi def link sliceType	Type
hi def link sliceString	String
hi def link sliceIncluded	String
hi def link sliceQualifier	Keyword
hi def link sliceInclude	Include
hi def link sliceGuard	PreProc
hi def link sliceBoolean	Boolean
hi def link sliceFloat	Number
hi def link sliceNumber	Number
hi def link sliceOctal	Number
hi def link sliceOctalZero	Special
hi def link sliceNumberError Special


let b:current_syntax = "slice"

" vim: ts=8
