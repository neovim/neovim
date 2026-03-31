" Vim syntax file
" Language:	Mojo
" Maintainer:	Mahmoud Abduljawad <me@mahmoudajawad.com>
" Last Change:	2023 Sep 09
" Credits:	Mahmoud Abduljawad <me@mahmoudajawad.com>
"         	Neil Schemenauer <nas@python.ca>
"		Dmitry Vasiliev
"
"		This is based on Vim Python highlighting
"
"		- introduced highlighting of doctests
"		- updated keywords, built-ins, and exceptions
"		- corrected regular expressions for
"
"		  * functions
"		  * decorators
"		  * strings
"		  * escapes
"		  * numbers
"		  * space error
"
"		- corrected synchronization
"		- more highlighting is ON by default, except
"		- space error highlighting is OFF by default
"
" Optional highlighting can be controlled using these variables.
"
"   let mojo_no_builtin_highlight = 1
"   let mojo_no_doctest_code_highlight = 1
"   let mojo_no_doctest_highlight = 1
"   let mojo_no_exception_highlight = 1
"   let mojo_no_number_highlight = 1
"   let mojo_space_error_highlight = 1
"
" All the options above can be switched on together.
"
"   let mojo_highlight_all = 1
"
" The use of Python 2 compatible syntax highlighting can be enforced.
" The straddling code (Python 2 and 3 compatible), up to Python 3.5,
" will be also supported.
"
"   let mojo_use_python2_syntax = 1
"
" This option will exclude all modern Python 3.6 or higher features.
"

" quit when a syntax file was already loaded.
if exists("b:current_syntax")
  finish
endif

" We need nocompatible mode in order to continue lines with backslashes.
" Original setting will be restored.
let s:cpo_save = &cpo
set cpo&vim

if exists("mojo_no_doctest_highlight")
  let mojo_no_doctest_code_highlight = 1
endif

if exists("mojo_highlight_all")
  if exists("mojo_no_builtin_highlight")
    unlet mojo_no_builtin_highlight
  endif
  if exists("mojo_no_doctest_code_highlight")
    unlet mojo_no_doctest_code_highlight
  endif
  if exists("mojo_no_doctest_highlight")
    unlet mojo_no_doctest_highlight
  endif
  if exists("mojo_no_exception_highlight")
    unlet mojo_no_exception_highlight
  endif
  if exists("mojo_no_number_highlight")
    unlet mojo_no_number_highlight
  endif
  let mojo_space_error_highlight = 1
endif

" These keywords are based on Python syntax highlight, and adds to it struct,
" fn, alias, var, let
"
syn keyword mojoStatement	False None True
syn keyword mojoStatement	as assert break continue del global
syn keyword mojoStatement	lambda nonlocal pass return with yield
syn keyword mojoStatement	class def nextgroup=mojoFunction skipwhite
syn keyword mojoStatement	struct fn nextgroup=mojoFunction skipwhite
syn keyword mojoStatement	alias var let
syn keyword mojoConditional	elif else if
syn keyword mojoRepeat		for while
syn keyword mojoOperator	and in is not or
syn keyword mojoException	except finally raise try
syn keyword mojoInclude		from import
syn keyword mojoAsync		async await

" Soft keywords
" These keywords do not mean anything unless used in the right context.
" See https://docs.python.org/3/reference/lexical_analysis.html#soft-keywords
" for more on this.
syn match   mojoConditional   "^\s*\zscase\%(\s\+.*:.*$\)\@="
syn match   mojoConditional   "^\s*\zsmatch\%(\s\+.*:\s*\%(#.*\)\=$\)\@="

" Decorators
" A dot must be allowed because of @MyClass.myfunc decorators.
syn match   mojoDecorator	"@" display contained
syn match   mojoDecoratorName	"@\s*\h\%(\w\|\.\)*" display contains=pythonDecorator

" Python 3.5 introduced the use of the same symbol for matrix multiplication:
" https://www.python.org/dev/peps/pep-0465/.  We now have to exclude the
" symbol from highlighting when used in that context.
" Single line multiplication.
syn match   mojoMatrixMultiply
      \ "\%(\w\|[])]\)\s*@"
      \ contains=ALLBUT,mojoDecoratorName,mojoDecorator,mojoFunction,mojoDoctestValue
      \ transparent
" Multiplication continued on the next line after backslash.
syn match   mojoMatrixMultiply
      \ "[^\\]\\\s*\n\%(\s*\.\.\.\s\)\=\s\+@"
      \ contains=ALLBUT,mojoDecoratorName,mojoDecorator,mojoFunction,mojoDoctestValue
      \ transparent
" Multiplication in a parenthesized expression over multiple lines with @ at
" the start of each continued line; very similar to decorators and complex.
syn match   mojoMatrixMultiply
      \ "^\s*\%(\%(>>>\|\.\.\.\)\s\+\)\=\zs\%(\h\|\%(\h\|[[(]\).\{-}\%(\w\|[])]\)\)\s*\n\%(\s*\.\.\.\s\)\=\s\+@\%(.\{-}\n\%(\s*\.\.\.\s\)\=\s\+@\)*"
      \ contains=ALLBUT,mojoDecoratorName,mojoDecorator,mojoFunction,mojoDoctestValue
      \ transparent

syn match   mojoFunction	"\h\w*" display contained

syn match   mojoComment	"#.*$" contains=mojoTodo,@Spell
syn keyword mojoTodo		FIXME NOTE NOTES TODO XXX contained

" Triple-quoted strings can contain doctests.
syn region  mojoString matchgroup=mojoQuotes
      \ start=+[uU]\=\z(['"]\)+ end="\z1" skip="\\\\\|\\\z1"
      \ contains=mojoEscape,@Spell
syn region  mojoString matchgroup=mojoTripleQuotes
      \ start=+[uU]\=\z('''\|"""\)+ end="\z1" keepend
      \ contains=mojoEscape,mojoSpaceError,mojoDoctest,@Spell
syn region  mojoRawString matchgroup=mojoQuotes
      \ start=+[uU]\=[rR]\z(['"]\)+ end="\z1" skip="\\\\\|\\\z1"
      \ contains=@Spell
syn region  mojoRawString matchgroup=pythonTripleQuotes
      \ start=+[uU]\=[rR]\z('''\|"""\)+ end="\z1" keepend
      \ contains=pythonSpaceError,mojoDoctest,@Spell

syn match   mojoEscape	+\\[abfnrtv'"\\]+ contained
syn match   mojoEscape	"\\\o\{1,3}" contained
syn match   mojoEscape	"\\x\x\{2}" contained
syn match   mojoEscape	"\%(\\u\x\{4}\|\\U\x\{8}\)" contained
" Python allows case-insensitive Unicode IDs: http://www.unicode.org/charts/
syn match   mojoEscape	"\\N{\a\+\%(\s\a\+\)*}" contained
syn match   mojoEscape	"\\$"

" It is very important to understand all details before changing the
" regular expressions below or their order.
" The word boundaries are *not* the floating-point number boundaries
" because of a possible leading or trailing decimal point.
" The expressions below ensure that all valid number literals are
" highlighted, and invalid number literals are not.  For example,
"
" - a decimal point in '4.' at the end of a line is highlighted,
" - a second dot in 1.0.0 is not highlighted,
" - 08 is not highlighted,
" - 08e0 or 08j are highlighted,
"
" and so on, as specified in the 'Python Language Reference'.
" https://docs.python.org/reference/lexical_analysis.html#numeric-literals
if !exists("mojo_no_number_highlight")
  " numbers (including complex)
  syn match   mojoNumber	"\<0[oO]\%(_\=\o\)\+\>"
  syn match   mojoNumber	"\<0[xX]\%(_\=\x\)\+\>"
  syn match   mojoNumber	"\<0[bB]\%(_\=[01]\)\+\>"
  syn match   mojoNumber	"\<\%([1-9]\%(_\=\d\)*\|0\+\%(_\=0\)*\)\>"
  syn match   mojoNumber	"\<\d\%(_\=\d\)*[jJ]\>"
  syn match   mojoNumber	"\<\d\%(_\=\d\)*[eE][+-]\=\d\%(_\=\d\)*[jJ]\=\>"
  syn match   mojoNumber
        \ "\<\d\%(_\=\d\)*\.\%([eE][+-]\=\d\%(_\=\d\)*\)\=[jJ]\=\%(\W\|$\)\@="
  syn match   mojoNumber
        \ "\%(^\|\W\)\zs\%(\d\%(_\=\d\)*\)\=\.\d\%(_\=\d\)*\%([eE][+-]\=\d\%(_\=\d\)*\)\=[jJ]\=\>"
endif

" The built-ins are added in the same order of appearance in Mojo stdlib docs
" https://docs.modular.com/mojo/lib.html
"
if !exists("mojo_no_builtin_highlight")
  " Built-in functions
  syn keyword mojoBuiltin	slice constrained debug_assert put_new_line print
  syn keyword mojoBuiltin	print_no_newline len range rebind element_type 
  syn keyword mojoBuiltin	ord chr atol isdigit index address string
  " Built-in types
  syn keyword mojoType		Byte ListLiteral CoroutineContext Coroutine DType
  syn keyword mojoType		dtype type invalid bool int8 si8 unit8 ui8 int16 
  syn keyword mojoType		si16 unit16 ui16 int32 si32 uint32 ui32 int64 
  syn keyword mojoType		si64 uint64 ui64 bfloat16 bf16 float16 f16 float32
  syn keyword mojoType		f32 float64 f64 Error FloatLiteral Int Attr SIMD 
  syn keyword mojoType		Int8 UInt8 Int16 UInt16 Int32 UInt32 Int64 UInt64
  syn keyword mojoType		Float16 Float32 Float64 element_type _65x13_type
  syn keyword mojoType		String StringLiteral StringRef Tuple AnyType
  syn keyword mojoType		NoneType None Lifetime
  " avoid highlighting attributes as builtins
  syn match   mojoAttribute	/\.\h\w*/hs=s+1
	\ contains=ALLBUT,mojoBuiltin,mojoFunction,mojoAsync
	\ transparent
endif

" From the 'Python Library Reference' class hierarchy at the bottom.
" http://docs.python.org/library/exceptions.html
if !exists("mojo_no_exception_highlight")
  " builtin base exceptions (used mostly as base classes for other exceptions)
  syn keyword mojoExceptions	BaseException Exception
  syn keyword mojoExceptions	ArithmeticError BufferError LookupError
  " builtin exceptions (actually raised)
  syn keyword mojoExceptions	AssertionError AttributeError EOFError
  syn keyword mojoExceptions	FloatingPointError GeneratorExit ImportError
  syn keyword mojoExceptions	IndentationError IndexError KeyError
  syn keyword mojoExceptions	KeyboardInterrupt MemoryError
  syn keyword mojoExceptions	ModuleNotFoundError NameError
  syn keyword mojoExceptions	NotImplementedError OSError OverflowError
  syn keyword mojoExceptions	RecursionError ReferenceError RuntimeError
  syn keyword mojoExceptions	StopAsyncIteration StopIteration SyntaxError
  syn keyword mojoExceptions	SystemError SystemExit TabError TypeError
  syn keyword mojoExceptions	UnboundLocalError UnicodeDecodeError
  syn keyword mojoExceptions	UnicodeEncodeError UnicodeError
  syn keyword mojoExceptions	UnicodeTranslateError ValueError
  syn keyword mojoExceptions	ZeroDivisionError
  " builtin exception aliases for OSError
  syn keyword mojoExceptions	EnvironmentError IOError WindowsError
  " builtin OS exceptions in Python 3
  syn keyword mojoExceptions	BlockingIOError BrokenPipeError
  syn keyword mojoExceptions	ChildProcessError ConnectionAbortedError
  syn keyword mojoExceptions	ConnectionError ConnectionRefusedError
  syn keyword mojoExceptions	ConnectionResetError FileExistsError
  syn keyword mojoExceptions	FileNotFoundError InterruptedError
  syn keyword mojoExceptions	IsADirectoryError NotADirectoryError
  syn keyword mojoExceptions	PermissionError ProcessLookupError TimeoutError
  " builtin warnings
  syn keyword mojoExceptions	BytesWarning DeprecationWarning FutureWarning
  syn keyword mojoExceptions	ImportWarning PendingDeprecationWarning
  syn keyword mojoExceptions	ResourceWarning RuntimeWarning
  syn keyword mojoExceptions	SyntaxWarning UnicodeWarning
  syn keyword mojoExceptions	UserWarning Warning
endif

if exists("mojo_space_error_highlight")
  " trailing whitespace
  syn match   mojoSpaceError	display excludenl "\s\+$"
  " mixed tabs and spaces
  syn match   mojoSpaceError	display " \+\t"
  syn match   mojoSpaceError	display "\t\+ "
endif

" Do not spell doctests inside strings.
" Notice that the end of a string, either ''', or """, will end the contained
" doctest too.  Thus, we do *not* need to have it as an end pattern.
if !exists("mojo_no_doctest_highlight")
  if !exists("mojo_no_doctest_code_highlight")
    syn region mojoDoctest
	  \ start="^\s*>>>\s" end="^\s*$"
	  \ contained contains=ALLBUT,mojoDoctest,mojoFunction,@Spell
    syn region mojoDoctestValue
	  \ start=+^\s*\%(>>>\s\|\.\.\.\s\|"""\|'''\)\@!\S\++ end="$"
	  \ contained
  else
    syn region mojoDoctest
	  \ start="^\s*>>>" end="^\s*$"
	  \ contained contains=@NoSpell
  endif
endif

" Sync at the beginning of class, function, or method definition.
syn sync match mojoSync grouphere NONE "^\%(def\|class\)\s\+\h\w*\s*[(:]"

" The default highlight links.  Can be overridden later.
hi def link mojoStatement		Statement
hi def link mojoConditional		Conditional
hi def link mojoRepeat			Repeat
hi def link mojoOperator		Operator
hi def link mojoException		Exception
hi def link mojoInclude			Include
hi def link mojoAsync			Statement
hi def link mojoDecorator		Define
hi def link mojoDecoratorName		Function
hi def link mojoFunction		Function
hi def link mojoComment			Comment
hi def link mojoTodo			Todo
hi def link mojoString			String
hi def link mojoRawString		String
hi def link mojoQuotes			String
hi def link mojoTripleQuotes		mojoQuotes
hi def link mojoEscape			Special
if !exists("mojo_no_number_highlight")
  hi def link mojoNumber		Number
endif
if !exists("mojo_no_builtin_highlight")
  hi def link mojoBuiltin		Function
  hi def link mojoType			Type
endif
if !exists("mojo_no_exception_highlight")
  hi def link mojoExceptions		Structure
endif
if exists("mojo_space_error_highlight")
  hi def link mojoSpaceError		Error
endif
if !exists("mojo_no_doctest_highlight")
  hi def link mojoDoctest		Special
  hi def link mojoDoctestValue	Define
endif

let b:current_syntax = "mojo"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:set sw=2 sts=2 ts=8 noet:
