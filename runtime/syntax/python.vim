" Vim syntax file
" Language:	Python
" Maintainer:	Zvezdan Petkovic <zpetkovic@acm.org>
" Last Change:	2022 Jun 28
" Credits:	Neil Schemenauer <nas@python.ca>
"		Dmitry Vasiliev
"
"		This version is a major rewrite by Zvezdan Petkovic.
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
"   let python_no_builtin_highlight = 1
"   let python_no_doctest_code_highlight = 1
"   let python_no_doctest_highlight = 1
"   let python_no_exception_highlight = 1
"   let python_no_number_highlight = 1
"   let python_space_error_highlight = 1
"
" All the options above can be switched on together.
"
"   let python_highlight_all = 1
"

" quit when a syntax file was already loaded.
if exists("b:current_syntax")
  finish
endif

" We need nocompatible mode in order to continue lines with backslashes.
" Original setting will be restored.
let s:cpo_save = &cpo
set cpo&vim

if exists("python_no_doctest_highlight")
  let python_no_doctest_code_highlight = 1
endif

if exists("python_highlight_all")
  if exists("python_no_builtin_highlight")
    unlet python_no_builtin_highlight
  endif
  if exists("python_no_doctest_code_highlight")
    unlet python_no_doctest_code_highlight
  endif
  if exists("python_no_doctest_highlight")
    unlet python_no_doctest_highlight
  endif
  if exists("python_no_exception_highlight")
    unlet python_no_exception_highlight
  endif
  if exists("python_no_number_highlight")
    unlet python_no_number_highlight
  endif
  let python_space_error_highlight = 1
endif

" Keep Python keywords in alphabetical order inside groups for easy
" comparison with the table in the 'Python Language Reference'
" https://docs.python.org/reference/lexical_analysis.html#keywords.
" Groups are in the order presented in NAMING CONVENTIONS in syntax.txt.
" Exceptions come last at the end of each group (class and def below).
"
" The list can be checked using:
"
" python3 -c 'import keyword, pprint; pprint.pprint(keyword.kwlist + keyword.softkwlist, compact=True)'
"
syn keyword pythonStatement	False None True
syn keyword pythonStatement	as assert break continue del global
syn keyword pythonStatement	lambda nonlocal pass return with yield
syn keyword pythonStatement	class def nextgroup=pythonFunction skipwhite
syn keyword pythonConditional	elif else if
syn keyword pythonRepeat	for while
syn keyword pythonOperator	and in is not or
syn keyword pythonException	except finally raise try
syn keyword pythonInclude	from import
syn keyword pythonAsync		async await

" Soft keywords
" These keywords do not mean anything unless used in the right context
" See https://docs.python.org/3/reference/lexical_analysis.html#soft-keywords 
" for more on this.
syn match   pythonConditional   "^\s*\zscase\%(\s\+.*:.*$\)\@="
syn match   pythonConditional   "^\s*\zsmatch\%(\s\+.*:\s*\%(#.*\)\=$\)\@="

" Decorators
" A dot must be allowed because of @MyClass.myfunc decorators.
syn match   pythonDecorator	"@" display contained
syn match   pythonDecoratorName	"@\s*\h\%(\w\|\.\)*" display contains=pythonDecorator

" Python 3.5 introduced the use of the same symbol for matrix multiplication:
" https://www.python.org/dev/peps/pep-0465/.  We now have to exclude the
" symbol from highlighting when used in that context.
" Single line multiplication.
syn match   pythonMatrixMultiply
      \ "\%(\w\|[])]\)\s*@"
      \ contains=ALLBUT,pythonDecoratorName,pythonDecorator,pythonFunction,pythonDoctestValue
      \ transparent
" Multiplication continued on the next line after backslash.
syn match   pythonMatrixMultiply
      \ "[^\\]\\\s*\n\%(\s*\.\.\.\s\)\=\s\+@"
      \ contains=ALLBUT,pythonDecoratorName,pythonDecorator,pythonFunction,pythonDoctestValue
      \ transparent
" Multiplication in a parenthesized expression over multiple lines with @ at
" the start of each continued line; very similar to decorators and complex.
syn match   pythonMatrixMultiply
      \ "^\s*\%(\%(>>>\|\.\.\.\)\s\+\)\=\zs\%(\h\|\%(\h\|[[(]\).\{-}\%(\w\|[])]\)\)\s*\n\%(\s*\.\.\.\s\)\=\s\+@\%(.\{-}\n\%(\s*\.\.\.\s\)\=\s\+@\)*"
      \ contains=ALLBUT,pythonDecoratorName,pythonDecorator,pythonFunction,pythonDoctestValue
      \ transparent

syn match   pythonFunction	"\h\w*" display contained

syn match   pythonComment	"#.*$" contains=pythonTodo,@Spell
syn keyword pythonTodo		FIXME NOTE NOTES TODO XXX contained

" Triple-quoted strings can contain doctests.
syn region  pythonString matchgroup=pythonQuotes
      \ start=+[uU]\=\z(['"]\)+ end="\z1" skip="\\\\\|\\\z1"
      \ contains=pythonEscape,@Spell
syn region  pythonString matchgroup=pythonTripleQuotes
      \ start=+[uU]\=\z('''\|"""\)+ skip=+\\["']+ end="\z1" keepend
      \ contains=pythonEscape,pythonSpaceError,pythonDoctest,@Spell
syn region  pythonRawString matchgroup=pythonQuotes
      \ start=+[uU]\=[rR]\z(['"]\)+ end="\z1" skip="\\\\\|\\\z1"
      \ contains=@Spell
syn region  pythonRawString matchgroup=pythonTripleQuotes
      \ start=+[uU]\=[rR]\z('''\|"""\)+ end="\z1" keepend
      \ contains=pythonSpaceError,pythonDoctest,@Spell

syn match   pythonEscape	+\\[abfnrtv'"\\]+ contained
syn match   pythonEscape	"\\\o\{1,3}" contained
syn match   pythonEscape	"\\x\x\{2}" contained
syn match   pythonEscape	"\%(\\u\x\{4}\|\\U\x\{8}\)" contained
" Python allows case-insensitive Unicode IDs: http://www.unicode.org/charts/
syn match   pythonEscape	"\\N{\a\+\%(\s\a\+\)*}" contained
syn match   pythonEscape	"\\$"

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
if !exists("python_no_number_highlight")
  " numbers (including longs and complex)
  syn match   pythonNumber	"\<0[oO]\=\o\+[Ll]\=\>"
  syn match   pythonNumber	"\<0[xX]\x\+[Ll]\=\>"
  syn match   pythonNumber	"\<0[bB][01]\+[Ll]\=\>"
  syn match   pythonNumber	"\<\%([1-9]\d*\|0\)[Ll]\=\>"
  syn match   pythonNumber	"\<\d\+[jJ]\>"
  syn match   pythonNumber	"\<\d\+[eE][+-]\=\d\+[jJ]\=\>"
  syn match   pythonNumber
	\ "\<\d\+\.\%([eE][+-]\=\d\+\)\=[jJ]\=\%(\W\|$\)\@="
  syn match   pythonNumber
	\ "\%(^\|\W\)\zs\d*\.\d\+\%([eE][+-]\=\d\+\)\=[jJ]\=\>"
endif

" Group the built-ins in the order in the 'Python Library Reference' for
" easier comparison.
" https://docs.python.org/library/constants.html
" http://docs.python.org/library/functions.html
" Python built-in functions are in alphabetical order.
"
" The list can be checked using:
"
" python3 -c 'import builtins, pprint; pprint.pprint(dir(builtins), compact=True)'
"
" The constants added by the `site` module are not listed below because they
" should not be used in programs, only in interactive interpreter.
" Similarly for some other attributes and functions `__`-enclosed from the
" output of the above command.
"
if !exists("python_no_builtin_highlight")
  " built-in constants
  " 'False', 'True', and 'None' are also reserved words in Python 3
  syn keyword pythonBuiltin	False True None
  syn keyword pythonBuiltin	NotImplemented Ellipsis __debug__
  " constants added by the `site` module
  syn keyword pythonBuiltin	quit exit copyright credits license
  " built-in functions
  syn keyword pythonBuiltin	abs all any ascii bin bool breakpoint bytearray
  syn keyword pythonBuiltin	bytes callable chr classmethod compile complex
  syn keyword pythonBuiltin	delattr dict dir divmod enumerate eval exec
  syn keyword pythonBuiltin	filter float format frozenset getattr globals
  syn keyword pythonBuiltin	hasattr hash help hex id input int isinstance
  syn keyword pythonBuiltin	issubclass iter len list locals map max
  syn keyword pythonBuiltin	memoryview min next object oct open ord pow
  syn keyword pythonBuiltin	print property range repr reversed round set
  syn keyword pythonBuiltin	setattr slice sorted staticmethod str sum super
  syn keyword pythonBuiltin	tuple type vars zip __import__
  " avoid highlighting attributes as builtins
  syn match   pythonAttribute	/\.\h\w*/hs=s+1
	\ contains=ALLBUT,pythonBuiltin,pythonFunction,pythonAsync
	\ transparent
endif

" From the 'Python Library Reference' class hierarchy at the bottom.
" http://docs.python.org/library/exceptions.html
if !exists("python_no_exception_highlight")
  " builtin base exceptions (used mostly as base classes for other exceptions)
  syn keyword pythonExceptions	BaseException Exception
  syn keyword pythonExceptions	ArithmeticError BufferError LookupError
  " builtin exceptions (actually raised)
  syn keyword pythonExceptions	AssertionError AttributeError EOFError
  syn keyword pythonExceptions	FloatingPointError GeneratorExit ImportError
  syn keyword pythonExceptions	IndentationError IndexError KeyError
  syn keyword pythonExceptions	KeyboardInterrupt MemoryError
  syn keyword pythonExceptions	ModuleNotFoundError NameError
  syn keyword pythonExceptions	NotImplementedError OSError OverflowError
  syn keyword pythonExceptions	RecursionError ReferenceError RuntimeError
  syn keyword pythonExceptions	StopAsyncIteration StopIteration SyntaxError
  syn keyword pythonExceptions	SystemError SystemExit TabError TypeError
  syn keyword pythonExceptions	UnboundLocalError UnicodeDecodeError
  syn keyword pythonExceptions	UnicodeEncodeError UnicodeError
  syn keyword pythonExceptions	UnicodeTranslateError ValueError
  syn keyword pythonExceptions	ZeroDivisionError
  " builtin exception aliases for OSError
  syn keyword pythonExceptions	EnvironmentError IOError WindowsError
  " builtin OS exceptions in Python 3
  syn keyword pythonExceptions	BlockingIOError BrokenPipeError
  syn keyword pythonExceptions	ChildProcessError ConnectionAbortedError
  syn keyword pythonExceptions	ConnectionError ConnectionRefusedError
  syn keyword pythonExceptions	ConnectionResetError FileExistsError
  syn keyword pythonExceptions	FileNotFoundError InterruptedError
  syn keyword pythonExceptions	IsADirectoryError NotADirectoryError
  syn keyword pythonExceptions	PermissionError ProcessLookupError TimeoutError
  " builtin warnings
  syn keyword pythonExceptions	BytesWarning DeprecationWarning FutureWarning
  syn keyword pythonExceptions	ImportWarning PendingDeprecationWarning
  syn keyword pythonExceptions	ResourceWarning RuntimeWarning
  syn keyword pythonExceptions	SyntaxWarning UnicodeWarning
  syn keyword pythonExceptions	UserWarning Warning
endif

if exists("python_space_error_highlight")
  " trailing whitespace
  syn match   pythonSpaceError	display excludenl "\s\+$"
  " mixed tabs and spaces
  syn match   pythonSpaceError	display " \+\t"
  syn match   pythonSpaceError	display "\t\+ "
endif

" Do not spell doctests inside strings.
" Notice that the end of a string, either ''', or """, will end the contained
" doctest too.  Thus, we do *not* need to have it as an end pattern.
if !exists("python_no_doctest_highlight")
  if !exists("python_no_doctest_code_highlight")
    syn region pythonDoctest
	  \ start="^\s*>>>\s" end="^\s*$"
	  \ contained contains=ALLBUT,pythonDoctest,pythonFunction,@Spell
    syn region pythonDoctestValue
	  \ start=+^\s*\%(>>>\s\|\.\.\.\s\|"""\|'''\)\@!\S\++ end="$"
	  \ contained
  else
    syn region pythonDoctest
	  \ start="^\s*>>>" end="^\s*$"
	  \ contained contains=@NoSpell
  endif
endif

" Sync at the beginning of class, function, or method definition.
syn sync match pythonSync grouphere NONE "^\%(def\|class\)\s\+\h\w*\s*[(:]"

" The default highlight links.  Can be overridden later.
hi def link pythonStatement		Statement
hi def link pythonConditional		Conditional
hi def link pythonRepeat		Repeat
hi def link pythonOperator		Operator
hi def link pythonException		Exception
hi def link pythonInclude		Include
hi def link pythonAsync			Statement
hi def link pythonDecorator		Define
hi def link pythonDecoratorName		Function
hi def link pythonFunction		Function
hi def link pythonComment		Comment
hi def link pythonTodo			Todo
hi def link pythonString		String
hi def link pythonRawString		String
hi def link pythonQuotes		String
hi def link pythonTripleQuotes		pythonQuotes
hi def link pythonEscape		Special
if !exists("python_no_number_highlight")
  hi def link pythonNumber		Number
endif
if !exists("python_no_builtin_highlight")
  hi def link pythonBuiltin		Function
endif
if !exists("python_no_exception_highlight")
  hi def link pythonExceptions		Structure
endif
if exists("python_space_error_highlight")
  hi def link pythonSpaceError		Error
endif
if !exists("python_no_doctest_highlight")
  hi def link pythonDoctest		Special
  hi def link pythonDoctestValue	Define
endif

let b:current_syntax = "python"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:set sw=2 sts=2 ts=8 noet:
