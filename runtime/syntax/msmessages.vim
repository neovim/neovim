" Vim syntax file
" Language:	MS Message Text files (*.mc)
" Maintainer:	Kevin Locke <kwl7@cornell.edu>
" Last Change:	2008 April 09
" Location:	http://kevinlocke.name/programs/vim/syntax/msmessages.vim

" See format description at <http://msdn2.microsoft.com/en-us/library/aa385646.aspx>
" This file is based on the rc.vim and c.vim

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Common MS Messages keywords
syn case ignore
syn keyword msmessagesIdentifier MessageIdTypedef
syn keyword msmessagesIdentifier SeverityNames
syn keyword msmessagesIdentifier FacilityNames
syn keyword msmessagesIdentifier LanguageNames
syn keyword msmessagesIdentifier OutputBase

syn keyword msmessagesIdentifier MessageId
syn keyword msmessagesIdentifier Severity
syn keyword msmessagesIdentifier Facility
syn keyword msmessagesIdentifier OutputBase

syn match msmessagesIdentifier /\<SymbolicName\>/ nextgroup=msmessagesIdentEq skipwhite
syn match msmessagesIdentEq transparent /=/ nextgroup=msmessagesIdentDef skipwhite contained
syn match msmessagesIdentDef display /\w\+/ contained
" Note:  The Language keyword is highlighted as part of an msmessagesLangEntry

" Set value
syn case match
syn region msmessagesSet	start="(" end=")" transparent fold contains=msmessagesName keepend
syn match msmessagesName /\w\+/ nextgroup=msmessagesSetEquals skipwhite contained
syn match msmessagesSetEquals /=/ display transparent nextgroup=msmessagesNumVal skipwhite contained
syn match msmessagesNumVal	display transparent "\<\d\|\.\d" contains=msmessagesNumber,msmessagesFloat,msmessagesOctalError,msmessagesOctal nextgroup=msmessagesValSep
syn match msmessagesValSep /:/ display nextgroup=msmessagesNameDef contained
syn match msmessagesNameDef /\w\+/ display contained


" Comments are converted to C source (by removing leading ;)
" So we highlight the comments as C
syn include @msmessagesC syntax/c.vim
unlet b:current_syntax
syn region msmessagesCComment matchgroup=msmessagesComment start=/;/ end=/$/ contains=@msmessagesC keepend

" String and Character constants
" Highlight special characters (those which have a escape) differently
syn case ignore
syn region msmessagesLangEntry start=/\<Language\>\s*=\s*\S\+\s*$/hs=e+1 end=/^\./ contains=msmessagesFormat,msmessagesLangEntryEnd,msmessagesLanguage keepend
syn match msmessagesLanguage /\<Language\(\s*=\)\@=/ contained
syn match msmessagesLangEntryEnd display /^\./ contained
syn case match
syn match msmessagesFormat display	/%[1-9]\d\?\(![-+0 #]*\d*\(\.\d\+\)\?\(h\|l\|ll\|I\|I32\|I64\)\?[aAcCdeEfgGinopsSuxX]!\)\?/ contained
syn match msmessagesFormat display	/%[0.%\\br]/ contained
syn match msmessagesFormat display	/%!\(\s\)\@=/ contained

" Integer number, or floating point number without a dot and with "f".
" Copied from c.vim
syn case ignore
"(long) integer
syn match msmessagesNumber	display contained "\d\+\(u\=l\{0,2}\|ll\=u\)\>"
"hex number
syn match msmessagesNumber	display contained "\<0x\x\+\(u\=l\{0,2}\|ll\=u\)\>"
" Flag the first zero of an octal number as something special
syn match msmessagesOctal	display contained "\<0\o\+\(u\=l\{0,2}\|ll\=u\)\>" contains=msmessagesOctalZero
syn match msmessagesOctalZero	display contained "\<0"
" flag an octal number with wrong digits
syn match msmessagesOctalError	display contained "\<0\o*[89]\d*"
syn match msmessagesFloat	display contained "\d\+f"
"floating point number, with dot, optional exponent
syn match msmessagesFloat	display contained "\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\="
"floating point number, starting with a dot, optional exponent
syn match msmessagesFloat	display contained "\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, without dot, with exponent
syn match msmessagesFloat	display contained "\d\+e[-+]\=\d\+[fl]\=\>"
"hexadecimal floating point number, optional leading digits, with dot, with exponent
syn match msmessagesFloat	display contained "0x\x*\.\x\+p[-+]\=\d\+[fl]\=\>"
"hexadecimal floating point number, with leading digits, optional dot, with exponent
syn match msmessagesFloat	display contained "0x\x\+\.\=p[-+]\=\d\+[fl]\=\>"

" Types (used in MessageIdTypedef statement)
syn case match
syn keyword msmessagesType	int long short char
syn keyword msmessagesType	signed unsigned
syn keyword msmessagesType	size_t ssize_t sig_atomic_t
syn keyword msmessagesType	int8_t int16_t int32_t int64_t
syn keyword msmessagesType	uint8_t uint16_t uint32_t uint64_t
syn keyword msmessagesType	int_least8_t int_least16_t int_least32_t int_least64_t
syn keyword msmessagesType	uint_least8_t uint_least16_t uint_least32_t uint_least64_t
syn keyword msmessagesType	int_fast8_t int_fast16_t int_fast32_t int_fast64_t
syn keyword msmessagesType	uint_fast8_t uint_fast16_t uint_fast32_t uint_fast64_t
syn keyword msmessagesType	intptr_t uintptr_t
syn keyword msmessagesType	intmax_t uintmax_t
" Add some Windows datatypes that will be common in msmessages files
syn keyword msmessagesType	BYTE CHAR SHORT SIZE_T SSIZE_T TBYTE TCHAR UCHAR USHORT
syn keyword msmessagesType	DWORD DWORDLONG DWORD32 DWORD64
syn keyword msmessagesType	INT INT32 INT64 UINT UINT32 UINT64
syn keyword msmessagesType	LONG LONGLONG LONG32 LONG64
syn keyword msmessagesType	ULONG ULONGLONG ULONG32 ULONG64

" Sync to language entries, since they should be most common
syn sync match msmessagesLangSync grouphere msmessagesLangEntry "\<Language\s*="
syn sync match msmessagesLangEndSync grouphere NONE "^\."

" Define the default highlighting.
hi def link msmessagesNumber		Number
hi def link msmessagesOctal		Number
hi def link msmessagesFloat		Float
hi def link msmessagesOctalError	msmessagesError
hi def link msmessagesSetError		msmessagesError
hi def link msmessagesError		Error
hi def link msmessagesLangEntry		String
hi def link msmessagesLangEntryEnd	Special
hi def link msmessagesComment		Comment
hi def link msmessagesFormat		msmessagesSpecial
hi def link msmessagesSpecial		SpecialChar

hi def link msmessagesType		Type
hi def link msmessagesIdentifier	Identifier
hi def link msmessagesLanguage		msmessagesIdentifier
hi def link msmessagesName		msmessagesIdentifier
hi def link msmessagesNameDef		Macro
hi def link msmessagesIdentDef		Macro
hi def link msmessagesValSep		Special
hi def link msmessagesNameErr		Error

let b:current_syntax = "msmessages"

" vim: ts=8
