" Vim syntax file
" Language:	awk, nawk, gawk, mawk
" Maintainer:	Antonio Colombo <azc100@gmail.com>
" Last Change:	2014 Oct 21

" AWK  ref.  is: Alfred V. Aho, Brian W. Kernighan, Peter J. Weinberger
" The AWK Programming Language, Addison-Wesley, 1988

" GAWK ref. is: Arnold D. Robbins
" Effective AWK Programming, Third Edition, O'Reilly, 2001
" Effective AWK Programming, Fourth Edition, O'Reilly, 2015
" (also available with the gawk source distribution)

" MAWK is a "new awk" meaning it implements AWK ref.
" mawk conforms to the Posix 1003.2 (draft 11.3)
" definition of the AWK language which contains a few features
" not described in the AWK book, and mawk provides a small number of extensions.

" TODO:
" Dig into the commented out syntax expressions below.

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syn clear
elseif exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" A bunch of useful Awk keywords
" AWK  ref. p. 188
syn keyword awkStatement	break continue delete exit
syn keyword awkStatement	function getline next
syn keyword awkStatement	print printf return
" GAWK ref. Chapter 7
syn keyword awkStatement	nextfile
"
" GAWK ref. Chapter 9, Functions
"
" Numeric Functions
syn keyword awkFunction	atan2 cos div exp int log rand sin sqrt srand
" String Manipulation Functions
syn keyword awkFunction	asort asort1 gensub gsub index length match 
syn keyword awkFunction	patsplit split sprintf strtonum sub substr
syn keyword awkFunction	tolower toupper
" Input Output Functions
syn keyword awkFunction	close fflush system
" Time Functions
syn keyword awkFunction	mktime strftime systime
" Bit Manipulation Functions
syn keyword awkFunction	and compl lshift or rshift xor
" Getting Type Function
syn keyword awkFunction	isarray
" String-Translation Functions
syn keyword awkFunction	bindtextdomain dcgettext dcngetext

syn keyword awkConditional	if else
syn keyword awkRepeat	while for

syn keyword awkTodo		contained TODO

syn keyword awkPatterns	BEGIN END

" GAWK ref. Chapter 7
" Built-in Variables That Control awk
syn keyword awkVariables        BINMODE CONVFMT FIELDWIDTHS FPAT FS
syn keyword awkVariables	IGNORECASE LINT OFMT OFS ORS PREC
syn keyword awkVariables	ROUNDMODE RS SUBSEP TEXTDOMAIN
" Built-in Variables That Convey Information
syn keyword awkVariables	ARGC ARGV ARGIND ENVIRON ERRNO FILENAME
syn keyword awkVariables	FNR NF FUNCTAB NR PROCINFO RLENGTH RSTART 
syn keyword awkVariables	RT SYMTAB

syn keyword awkRepeat	do

" Octal format character.
syn match   awkSpecialCharacter display contained "\\[0-7]\{1,3\}"
syn keyword awkStatement	func nextfile
" Hex   format character.
syn match   awkSpecialCharacter display contained "\\x[0-9A-Fa-f]\+"

syn match   awkFieldVars	"\$\d\+"

"catch errors caused by wrong parenthesis
syn region	awkParen	transparent start="(" end=")" contains=ALLBUT,awkParenError,awkSpecialCharacter,awkArrayElement,awkArrayArray,awkTodo,awkRegExp,awkBrktRegExp,awkBrackets,awkCharClass
syn match	awkParenError	display ")"
syn match	awkInParen	display contained "[{}]"

" 64 lines for complex &&'s, and ||'s in a big "if"
syn sync ccomment awkParen maxlines=64

" Search strings & Regular Expressions therein.
syn region  awkSearch	oneline start="^[ \t]*/"ms=e start="\(,\|!\=\~\)[ \t]*/"ms=e skip="\\\\\|\\/" end="/" contains=awkBrackets,awkRegExp,awkSpecialCharacter
syn region  awkBrackets	contained start="\[\^\]\="ms=s+2 start="\[[^\^]"ms=s+1 end="\]"me=e-1 contains=awkBrktRegExp,awkCharClass
syn region  awkSearch	oneline start="[ \t]*/"hs=e skip="\\\\\|\\/" end="/" contains=awkBrackets,awkRegExp,awkSpecialCharacter

syn match   awkCharClass	contained "\[:[^:\]]*:\]"
syn match   awkBrktRegExp	contained "\\.\|.\-[^]]"
syn match   awkRegExp	contained "/\^"ms=s+1
syn match   awkRegExp	contained "\$/"me=e-1
syn match   awkRegExp	contained "[?.*{}|+]"

" String and Character constants
" Highlight special characters (those which have a backslash) differently
syn region  awkString	start=+"+  skip=+\\\\\|\\"+  end=+"+  contains=@Spell,awkSpecialCharacter,awkSpecialPrintf
syn match   awkSpecialCharacter contained "\\."

" Some of these combinations may seem weird, but they work.
syn match   awkSpecialPrintf	contained "%[-+ #]*\d*\.\=\d*[cdefgiosuxEGX%]"

" Numbers, allowing signs (both -, and +)
" Integer number.
syn match  awkNumber		display "[+-]\=\<\d\+\>"
" Floating point number.
syn match  awkFloat		display "[+-]\=\<\d\+\.\d+\>"
" Floating point number, starting with a dot.
syn match  awkFloat		display "[+-]\=\<.\d+\>"
syn case ignore
"floating point number, with dot, optional exponent
syn match  awkFloat	display "\<\d\+\.\d*\(e[-+]\=\d\+\)\=\>"
"floating point number, starting with a dot, optional exponent
syn match  awkFloat	display "\.\d\+\(e[-+]\=\d\+\)\=\>"
"floating point number, without dot, with exponent
syn match  awkFloat	display "\<\d\+e[-+]\=\d\+\>"
syn case match

"syn match  awkIdentifier	"\<[a-zA-Z_][a-zA-Z0-9_]*\>"

" Arithmetic operators: +, and - take care of ++, and --
syn match   awkOperator	"+\|-\|\*\|/\|%\|="
syn match   awkOperator	"+=\|-=\|\*=\|/=\|%="
syn match   awkOperator	"^\|^="

" Comparison expressions.
syn match   awkExpression	"==\|>=\|=>\|<=\|=<\|\!="
syn match   awkExpression	"\~\|\!\~"
syn match   awkExpression	"?\|:"
syn keyword awkExpression	in

" Boolean Logic (OR, AND, NOT)
"syn match  awkBoolLogic	"||\|&&\|\!"

" This is overridden by less-than & greater-than.
" Put this above those to override them.
" Put this in a 'match "\<printf\=\>.*;\="' to make it not override
" less/greater than (most of the time), but it won't work yet because
" keywords always have precedence over match & region.
" File I/O: (print foo, bar > "filename") & for nawk (getline < "filename")
"syn match  awkFileIO		contained ">"
"syn match  awkFileIO		contained "<"

" Expression separators: ';' and ','
syn match  awkSemicolon	";"
syn match  awkComma		","

syn match  awkComment	"#.*" contains=@Spell,awkTodo

syn match  awkLineSkip	"\\$"

" Highlight array element's (recursive arrays allowed).
" Keeps nested array names' separate from normal array elements.
" Keeps numbers separate from normal array elements (variables).
syn match  awkArrayArray	contained "[^][, \t]\+\["me=e-1
syn match  awkArrayElement      contained "[^][, \t]\+"
syn region awkArray		transparent start="\[" end="\]" contains=awkArray,awkArrayElement,awkArrayArray,awkNumber,awkFloat

" 10 should be enough.
" (for the few instances where it would be more than "oneline")
syn sync ccomment awkArray maxlines=10

" define the default highlighting
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_awk_syn_inits")
  if version < 508
    let did_awk_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink awkConditional		Conditional
  HiLink awkFunction		Function
  HiLink awkRepeat		Repeat
  HiLink awkStatement		Statement

  HiLink awkString		String
  HiLink awkSpecialPrintf	Special
  HiLink awkSpecialCharacter	Special

  HiLink awkSearch		String
  HiLink awkBrackets		awkRegExp
  HiLink awkBrktRegExp		awkNestRegExp
  HiLink awkCharClass		awkNestRegExp
  HiLink awkNestRegExp		Keyword
  HiLink awkRegExp		Special

  HiLink awkNumber		Number
  HiLink awkFloat		Float

  HiLink awkFileIO		Special
  HiLink awkOperator		Special
  HiLink awkExpression		Special
  HiLink awkBoolLogic		Special

  HiLink awkPatterns		Special
  HiLink awkVariables		Special
  HiLink awkFieldVars		Special

  HiLink awkLineSkip		Special
  HiLink awkSemicolon		Special
  HiLink awkComma		Special
  "HiLink awkIdentifier		Identifier

  HiLink awkComment		Comment
  HiLink awkTodo		Todo

  " Change this if you want nested array names to be highlighted.
  HiLink awkArrayArray		awkArray
  HiLink awkArrayElement	Special

  HiLink awkParenError		awkError
  HiLink awkInParen		awkError
  HiLink awkError		Error

  delcommand HiLink
endif

let b:current_syntax = "awk"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8
