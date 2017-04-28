" Vim syntax file
" Language:	Pike
" Maintainer:	Francesco Chemolli <kinkie@kame.usr.dsi.unimi.it>
" Last Change:	2001 May 10

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" A bunch of useful C keywords
syn keyword pikeStatement	goto break return continue
syn keyword pikeLabel		case default
syn keyword pikeConditional	if else switch
syn keyword pikeRepeat		while for foreach do
syn keyword pikeStatement	gauge destruct lambda inherit import typeof
syn keyword pikeException	catch
syn keyword pikeType		inline nomask private protected public static


syn keyword pikeTodo contained	TODO FIXME XXX

" String and Character constants
" Highlight special characters (those which have a backslash) differently
syn match pikeSpecial contained	"\\[0-7][0-7][0-7]\=\|\\."
syn region pikeString		start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=pikeSpecial
syn match pikeCharacter		"'[^\\]'"
syn match pikeSpecialCharacter	"'\\.'"
syn match pikeSpecialCharacter	"'\\[0-7][0-7]'"
syn match pikeSpecialCharacter	"'\\[0-7][0-7][0-7]'"

" Compound data types
syn region pikeCompoundType start='({' contains=pikeString,pikeCompoundType,pikeNumber,pikeFloat end='})'
syn region pikeCompoundType start='(\[' contains=pikeString,pikeCompoundType,pikeNumber,pikeFloat end='\])'
syn region pikeCompoundType start='(<' contains=pikeString,pikeCompoundType,pikeNumber,pikeFloat end='>)'

"catch errors caused by wrong parenthesis
syn region pikeParen		transparent start='([^{[<(]' end=')' contains=ALLBUT,pikeParenError,pikeIncluded,pikeSpecial,pikeTodo,pikeUserLabel,pikeBitField
syn match pikeParenError		")"
syn match pikeInParen contained	"[^(][{}][^)]"

"integer number, or floating point number without a dot and with "f".
syn case ignore
syn match pikeNumber		"\<\d\+\(u\=l\=\|lu\|f\)\>"
"floating point number, with dot, optional exponent
syn match pikeFloat		"\<\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, starting with a dot, optional exponent
syn match pikeFloat		"\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, without dot, with exponent
syn match pikeFloat		"\<\d\+e[-+]\=\d\+[fl]\=\>"
"hex number
syn match pikeNumber		"\<0x[0-9a-f]\+\(u\=l\=\|lu\)\>"
"syn match pikeIdentifier	"\<[a-z_][a-z0-9_]*\>"
syn case match
" flag an octal number with wrong digits
syn match pikeOctalError		"\<0[0-7]*[89]"

if exists("c_comment_strings")
  " A comment can contain pikeString, pikeCharacter and pikeNumber.
  " But a "*/" inside a pikeString in a pikeComment DOES end the comment!  So we
  " need to use a special type of pikeString: pikeCommentString, which also ends on
  " "*/", and sees a "*" at the start of the line as comment again.
  " Unfortunately this doesn't very well work for // type of comments :-(
  syntax match pikeCommentSkip	contained "^\s*\*\($\|\s\+\)"
  syntax region pikeCommentString	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ end=+\*/+me=s-1 contains=pikeSpecial,pikeCommentSkip
  syntax region pikeComment2String	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ end="$" contains=pikeSpecial
  syntax region pikeComment	start="/\*" end="\*/" contains=pikeTodo,pikeCommentString,pikeCharacter,pikeNumber,pikeFloat
  syntax match  pikeComment	"//.*" contains=pikeTodo,pikeComment2String,pikeCharacter,pikeNumber
  syntax match  pikeComment	"#\!.*" contains=pikeTodo,pikeComment2String,pikeCharacter,pikeNumber
else
  syn region pikeComment		start="/\*" end="\*/" contains=pikeTodo
  syn match pikeComment		"//.*" contains=pikeTodo
  syn match pikeComment		"#!.*" contains=pikeTodo
endif
syntax match pikeCommentError	"\*/"

syn keyword pikeOperator	sizeof
syn keyword pikeType		int string void float mapping array multiset mixed
syn keyword pikeType		program object function

syn region pikePreCondit	start="^\s*#\s*\(if\>\|ifdef\>\|ifndef\>\|elif\>\|else\>\|endif\>\)" skip="\\$" end="$" contains=pikeComment,pikeString,pikeCharacter,pikeNumber,pikeCommentError
syn region pikeIncluded contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match pikeIncluded contained "<[^>]*>"
syn match pikeInclude		"^\s*#\s*include\>\s*["<]" contains=pikeIncluded
"syn match pikeLineSkip	"\\$"
syn region pikeDefine		start="^\s*#\s*\(define\>\|undef\>\)" skip="\\$" end="$" contains=ALLBUT,pikePreCondit,pikeIncluded,pikeInclude,pikeDefine,pikeInParen
syn region pikePreProc		start="^\s*#\s*\(pragma\>\|line\>\|warning\>\|warn\>\|error\>\)" skip="\\$" end="$" contains=ALLBUT,pikePreCondit,pikeIncluded,pikeInclude,pikeDefine,pikeInParen

" Highlight User Labels
syn region	pikeMulti		transparent start='?' end=':' contains=ALLBUT,pikeIncluded,pikeSpecial,pikeTodo,pikeUserLabel,pikeBitField
" Avoid matching foo::bar() in C++ by requiring that the next char is not ':'
syn match	pikeUserLabel	"^\s*\I\i*\s*:$"
syn match	pikeUserLabel	";\s*\I\i*\s*:$"ms=s+1
syn match	pikeUserLabel	"^\s*\I\i*\s*:[^:]"me=e-1
syn match	pikeUserLabel	";\s*\I\i*\s*:[^:]"ms=s+1,me=e-1

" Avoid recognizing most bitfields as labels
syn match	pikeBitField	"^\s*\I\i*\s*:\s*[1-9]"me=e-1
syn match	pikeBitField	";\s*\I\i*\s*:\s*[1-9]"me=e-1

syn sync ccomment pikeComment minlines=10

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link pikeLabel		Label
hi def link pikeUserLabel		Label
hi def link pikeConditional	Conditional
hi def link pikeRepeat		Repeat
hi def link pikeCharacter		Character
hi def link pikeSpecialCharacter pikeSpecial
hi def link pikeNumber		Number
hi def link pikeFloat		Float
hi def link pikeOctalError		pikeError
hi def link pikeParenError		pikeError
hi def link pikeInParen		pikeError
hi def link pikeCommentError	pikeError
hi def link pikeOperator		Operator
hi def link pikeInclude		Include
hi def link pikePreProc		PreProc
hi def link pikeDefine		Macro
hi def link pikeIncluded		pikeString
hi def link pikeError		Error
hi def link pikeStatement		Statement
hi def link pikePreCondit		PreCondit
hi def link pikeType		Type
hi def link pikeCommentError	pikeError
hi def link pikeCommentString	pikeString
hi def link pikeComment2String	pikeString
hi def link pikeCommentSkip	pikeComment
hi def link pikeString		String
hi def link pikeComment		Comment
hi def link pikeSpecial		SpecialChar
hi def link pikeTodo		Todo
hi def link pikeException		pikeStatement
hi def link pikeCompoundType	Constant
"hi def link pikeIdentifier	Identifier


let b:current_syntax = "pike"

" vim: ts=8
