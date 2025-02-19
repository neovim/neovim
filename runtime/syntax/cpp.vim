" Vim syntax file
" Language:	C++
" Current Maintainer:	vim-jp (https://github.com/vim-jp/vim-cpp)
" Previous Maintainer:	Ken Shan <ccshan@post.harvard.edu>
" Last Change:	2024 May 04
"   2024 May 04 by Vim Project (fix digit separator in octals and floats)

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" inform C syntax that the file was included from cpp.vim
let b:filetype_in_cpp_family = 1

" Read the C syntax to start with
runtime! syntax/c.vim
unlet b:current_syntax
unlet b:filetype_in_cpp_family

" C++ extensions
syn keyword cppStatement	new delete this friend using
syn keyword cppAccess		public protected private
syn keyword cppModifier		inline virtual explicit export
syn keyword cppType		bool wchar_t
syn keyword cppExceptions	throw try catch
syn keyword cppOperator		operator typeid
syn keyword cppOperator		and bitor or xor compl bitand and_eq or_eq xor_eq not not_eq
syn match cppCast		"\<\(const\|static\|dynamic\|reinterpret\)_cast\s*<"me=e-1
syn match cppCast		"\<\(const\|static\|dynamic\|reinterpret\)_cast\s*$"
syn keyword cppStorageClass	mutable
syn keyword cppStructure	class typename template namespace
syn keyword cppBoolean		true false
syn keyword cppConstant		__cplusplus

" C++ 11 extensions
if !exists("cpp_no_cpp11")
  syn keyword cppModifier	override final
  syn keyword cppType		nullptr_t auto
  syn keyword cppExceptions	noexcept
  syn keyword cppStorageClass	constexpr decltype thread_local
  syn keyword cppConstant	nullptr
  syn keyword cppConstant	ATOMIC_FLAG_INIT ATOMIC_VAR_INIT
  syn keyword cppConstant	ATOMIC_BOOL_LOCK_FREE ATOMIC_CHAR_LOCK_FREE
  syn keyword cppConstant	ATOMIC_CHAR16_T_LOCK_FREE ATOMIC_CHAR32_T_LOCK_FREE
  syn keyword cppConstant	ATOMIC_WCHAR_T_LOCK_FREE ATOMIC_SHORT_LOCK_FREE
  syn keyword cppConstant	ATOMIC_INT_LOCK_FREE ATOMIC_LONG_LOCK_FREE
  syn keyword cppConstant	ATOMIC_LLONG_LOCK_FREE ATOMIC_POINTER_LOCK_FREE
  syn region cppRawString	matchgroup=cppRawStringDelimiter start=+\%(u8\|[uLU]\)\=R"\z([[:alnum:]_{}[\]#<>%:;.?*\+\-/\^&|~!=,"']\{,16}\)(+ end=+)\z1"\(sv\|s\|_[_a-zA-Z][_a-zA-Z0-9]*\)\=+ contains=@Spell
  syn match cppCast		"\<\(const\|static\|dynamic\)_pointer_cast\s*<"me=e-1
  syn match cppCast		"\<\(const\|static\|dynamic\)_pointer_cast\s*$"
endif

" C++ 14 extensions
if !exists("cpp_no_cpp14")
  syn match cppNumbers		display transparent "\<\d\|\.\d" contains=cppNumber,cppFloat
  syn match cppNumber		display contained "\<0\([Uu]\=\([Ll]\|LL\|ll\)\|\([Ll]\|LL\|ll\)\=[Uu]\|i[fl]\=\|h\|min\|s\|ms\|us\|ns\|_\i*\)\=\>"
  syn match cppNumber		display contained "\<[1-9]\('\=\d\+\)*\([Uu]\=\([Ll]\|LL\|ll\)\|\([Ll]\|LL\|ll\)\=[Uu]\|i[fl]\=\|h\|min\|s\|ms\|us\|ns\|_\i*\)\=\>"
  syn match cppNumber		display contained "\<0\('\=\o\+\)\+\([Uu]\=\([Ll]\|LL\|ll\)\|\([Ll]\|LL\|ll\)\=[Uu]\|i[fl]\=\|h\|min\|s\|ms\|us\|ns\|_\i*\)\=\>"
  syn match cppNumber		display contained "\<0b[01]\('\=[01]\+\)*\([Uu]\=\([Ll]\|LL\|ll\)\|\([Ll]\|LL\|ll\)\=[Uu]\|i[fl]\=\|h\|min\|s\|ms\|us\|ns\|_\i*\)\=\>"
  syn match cppNumber		display contained "\<0x\x\('\=\x\+\)*\([Uu]\=\([Ll]\|LL\|ll\)\|\([Ll]\|LL\|ll\)\=[Uu]\|i[fl]\=\|h\|min\|s\|ms\|us\|ns\|_\i*\)\=\>"
  syn match cppFloat		display contained "\<\d\('\=\d\+\)*\.\(\d\('\=\d\+\)*\)\=\(e[-+]\=\d\+\)\=\([FfLl]\|i[fl]\=\|h\|min\|s\|ms\|us\|ns\|_\i*\)\=\>"
  syn match cppFloat		display contained "\.\d\('\=\d\+\)*\(e[-+]\=\d\+\)\=\([FfLl]\|i[fl]\=\|h\|min\|s\|ms\|us\|ns\|_\i*\)\=\>"
  syn match cppFloat		display contained "\<\d\+e[-+]\=\d\+\([FfLl]\|i[fl]\=\|h\|min\|s\|ms\|us\|ns\|_\i*\)\=\>"
  syn region cppString		start=+\(L\|u\|u8\|U\)\="+ skip=+\\\\\|\\"\|\\$+ excludenl end=+"\(sv\|s\|_\i*\)\=+ end='$' contains=cSpecial,cFormat,@Spell
endif

" C++ 17 extensions
if !exists("cpp_no_cpp17")
  syn match cppCast		"\<reinterpret_pointer_cast\s*<"me=e-1
  syn match cppCast		"\<reinterpret_pointer_cast\s*$"
  syn match cppFloat		display contained "\<0x\x*\.\x\+p[-+]\=\d\+\([FfLl]\|i[fl]\=\|h\|min\|s\|ms\|us\|ns\|_\i*\)\=\>"
  syn match cppFloat		display contained "\<0x\x\+\.\=p[-+]\=\d\+\([FfLl]\|i[fl]\=\|h\|min\|s\|ms\|us\|ns\|_\i*\)\=\>"

  " TODO: push this up to c.vim if/when supported in C23
  syn match cppCharacter	"u8'[^\\]'"
  syn match cppCharacter	"u8'[^']*'" contains=cSpecial
  if exists("c_gnu")
    syn match cppSpecialError	  "u8'\\[^'\"?\\abefnrtv]'"
    syn match cppSpecialCharacter "u8'\\['\"?\\abefnrtv]'"
  else
    syn match cppSpecialError	  "u8'\\[^'\"?\\abfnrtv]'"
    syn match cppSpecialCharacter "u8'\\['\"?\\abfnrtv]'"
  endif
  syn match cppSpecialCharacter display "u8'\\\o\{1,3}'"
  syn match cppSpecialCharacter display "u8'\\x\x\+'"

endif

" C++ 20 extensions
if !exists("cpp_no_cpp20")
  syn match cppNumber		display contained "\<0\(y\|d\)\>"
  syn match cppNumber		display contained "\<[1-9]\('\=\d\+\)*\(y\|d\)\>"
  syn match cppNumber		display contained "\<0\o\+\(y\|d\)\>"
  syn match cppNumber		display contained "\<0b[01]\('\=[01]\+\)*\(y\|d\)\>"
  syn match cppNumber		display contained "\<0x\x\('\=\x\+\)*\(y\|d\)\>"
  syn keyword cppStatement	co_await co_return co_yield requires
  syn keyword cppStorageClass	consteval constinit
  syn keyword cppStructure	concept
  syn keyword cppType		char8_t
  syn keyword cppModule		import module export
endif

" The minimum and maximum operators in GNU C++
syn match cppMinMax "[<>]?"

" Default highlighting
hi def link cppAccess		cppStatement
hi def link cppCast		cppStatement
hi def link cppExceptions		Exception
hi def link cppOperator		Operator
hi def link cppStatement		Statement
hi def link cppModifier		Type
hi def link cppType		Type
hi def link cppStorageClass	StorageClass
hi def link cppStructure		Structure
hi def link cppBoolean		Boolean
hi def link cppCharacter		cCharacter
hi def link cppSpecialCharacter		cSpecialCharacter
hi def link cppSpecialError		cSpecialError
hi def link cppConstant		Constant
hi def link cppRawStringDelimiter	Delimiter
hi def link cppRawString		String
hi def link cppString		String
hi def link cppNumber		Number
hi def link cppFloat		Number
hi def link cppModule		Include

let b:current_syntax = "cpp"

" vim: ts=8
