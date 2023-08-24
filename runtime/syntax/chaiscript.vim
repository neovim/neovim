" Vim syntax file
" Language:	ChaiScript
" Maintainer:	Jason Turner <lefticus 'at' gmail com>

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
end

syn case match

" syncing method
syn sync fromstart

" Strings
syn region chaiscriptString        start=+"+ end=+"+ skip=+\\\\\|\\"+ contains=chaiscriptSpecial,chaiscriptEval,@Spell

" Escape characters
syn match  chaiscriptSpecial       contained "\\[\\abfnrtv\'\"]\|\\\d\{,3}" 

" String evals
syn region chaiscriptEval          contained start="${" end="}" 
 
" integer number
syn match  chaiscriptNumber        "\<\d\+\>"

" floating point number, with dot, optional exponent
syn match  chaiscriptFloat         "\<\d\+\.\d*\%(e[-+]\=\d\+\)\=\>"

" floating point number, starting with a dot, optional exponent
syn match  chaiscriptFloat         "\.\d\+\%(e[-+]\=\d\+\)\=\>"

" floating point number, without dot, with exponent
syn match  chaiscriptFloat         "\<\d\+e[-+]\=\d\+\>"

" Hex strings
syn match  chaiscriptNumber        "\<0x\x\+\>"

" Binary strings
syn match  chaiscriptNumber        "\<0b[01]\+\>"

" Various language features
syn keyword chaiscriptCond         if else
syn keyword chaiscriptRepeat       while for do
syn keyword chaiscriptStatement    break continue return
syn keyword chaiscriptExceptions   try catch throw

"Keyword
syn keyword chaiscriptKeyword      def true false attr

"Built in types
syn keyword chaiscriptType         fun var

"Built in funcs, keep it simple
syn keyword chaiscriptFunc         eval throw

"Let's treat all backtick operator function lookups as built in too
syn region  chaiscriptFunc         matchgroup=chaiscriptFunc start="`" end="`"

" Account for the "[1..10]" syntax, treating it as an operator
" Intentionally leaving out all of the normal, well known operators
syn match   chaiscriptOperator     "\.\."

" Guard separator as an operator
syn match   chaiscriptOperator     ":"

" Comments
syn match   chaiscriptComment      "//.*$" contains=@Spell
syn region  chaiscriptComment      matchgroup=chaiscriptComment start="/\*" end="\*/" contains=@Spell



hi def link chaiscriptExceptions	Exception
hi def link chaiscriptKeyword		Keyword
hi def link chaiscriptStatement		Statement
hi def link chaiscriptRepeat		Repeat
hi def link chaiscriptString		String
hi def link chaiscriptNumber		Number
hi def link chaiscriptFloat		Float
hi def link chaiscriptOperator		Operator
hi def link chaiscriptConstant		Constant
hi def link chaiscriptCond		Conditional
hi def link chaiscriptFunction		Function
hi def link chaiscriptComment		Comment
hi def link chaiscriptTodo		Todo
hi def link chaiscriptError		Error
hi def link chaiscriptSpecial		SpecialChar
hi def link chaiscriptFunc		Identifier
hi def link chaiscriptType		Type
hi def link chaiscriptEval	        Special

let b:current_syntax = "chaiscript"

" vim: nowrap sw=2 sts=2 ts=8 noet
