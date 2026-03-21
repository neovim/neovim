" Vim syntax file
" Language:     Handlebars
" Maintainer:   Devin Weaver
" Last Change:  2026 Feb 20
" Origin:       https://github.com/joukevandermaas/vim-ember-hbs
" Credits:      Jouke van der Maas
" License:      MIT
" The MIT License (MIT)
"
" Copyright (c) 2026 Devin Weaver
" Copyright (c) 2015 Jouke van der Maas
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in all
" copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
" SOFTWARE.

if exists("b:current_syntax")
  finish
endif

runtime! syntax/html.vim
syntax cluster htmlPreproc add=hbsComponent,hbsMustache,hbsUnescaped,hbsMustacheBlock,hbsComment,hbsElseBlock,hbsEscapedMustache

syntax match hbsEscapedMustache "\v\\\{\{"

syntax region hbsComponent matchgroup=hbsComponentStatement start="\v\<\/?:?\a+(\.\a+|::-?\a+)*" end="\v\/?\>" keepend
syntax region hbsMustache matchgroup=hbsHandles start="\v\{\{" skip="\v\\\}\}" end="\v\}\}" containedin=hbsComponent,hbsString keepend
syntax region hbsMustacheBlock matchgroup=hbsHandles start="\v\{\{[#/]" skip="\v\\\}\}" end="\v\}\}" keepend
" modern hbs supports {{else <block>}} where <block> starts a new block
syntax region hbsElseBlock matchgroup=hbsHandles start="\v\{\{else\ "rs=e-5 skip="\v\\\}\}" end="\v\}\}" keepend

syntax region hbsPencil matchgroup=hbsOperator start="\v\(" end="\v\)" contained containedin=hbsMustache,hbsMustacheBlock,hbsElseBlock,hbsPencil

" identifier is any word inside a mustache or a pencil that is not followed by a = sign (see hbsArg below)
syntax match hbsIdentifier "\v(\(|\{\{[#/]?)@<!<(\w+)|(\@\w+)>" contained containedin=hbsMustache,hbsMustacheBlock,hbsPencil,hbsElseBlock,hbsStatement

" unescaped are special forms of mustaches that don't have other stuff except for an identifier in it
syntax region hbsUnescaped matchgroup=hbsUnescapedHandles start="\v\{\{\{" skip="\v\\\}\}\}" end="\v\}\}\}" keepend
syntax match hbsUnescapedIdentifier "\v(\{\{\{)@<=<\S+>(\}\}\})" contained containedin=hbsUnescaped

syntax match hbsMustacheName "\v(\{\{[#/]?)@<=<\S+>" contained containedin=hbsMustache,hbsMustacheBlock,hbsPencil
syntax match hbsPencilName "\v(\()@<=<\S+>" contained containedin=hbsMustache,hbsMustacheBlock,hbsPencil
syntax match hbsBuiltInHelper "\v\(@<=<(query-params|mut|fn|array|hash|get|action|unbound|concat)>" contained containedin=hbsPencil
syntax match hbsBuiltInHelper "\v(\{\{)@<=<(textarea|mut|fn|array|hash|input|get|action|on|input|unbound)>" contained containedin=hbsMustache
syntax match hbsBuiltInHelper "\v(\{\{[#/]?)@<=<(component|with|link\-to)>" contained containedin=hbsMustacheBlock,hbsElseBlock
syntax match hbsBuiltInHelperInElse "\v(\{\{else\ )@<=<(component|link\-to)>" contained containedin=hbsMustacheBlock,hbsElseBlock
syntax match hbsControlFlow "\v(\{\{)@<=<else>( ?)@=" contained containedin=hbsElseBlock
syntax match hbsControlFlow "\v\(@<=<(if|unless)>" contained containedin=hbsPencil
syntax match hbsControlFlow "\v(\{\{)@<=<(debugger|unless|yield|outlet|else)>" contained containedin=hbsMustache
syntax match hbsControlFlow "\v(\{\{[#/]?)@<=<(with|let|if|each(\-in)?|unless)>" contained containedin=hbsMustacheBlock,hbsElseBlock
syntax match hbsKeyword "\v\s+as\s+" contained containedin=hbsComponent,hbsMustacheBlock,hbsElseBlock
syntax region hbsStatement matchgroup=hbsDelimiter start="\v\|" end="\v\|" contained containedin=hbsComponent,hbsMustacheBlock,hbsElseBlock

syntax region hbsString matchgroup=hbsString start=/\v\"/ skip=/\v\\\"/ end=/\v\"/ extend contained containedin=hbsComponent,hbsMustache,hbsMustacheBlock,hbsPencil,hbsElseBlock
syntax region hbsString matchgroup=hbsString start=/\v\'/ skip=/\v\\\'/ end=/\v\'/ extend contained containedin=hbsComponent,hbsMustache,hbsMustacheBlock,hbsPencil,hbsElseBlock
syntax match hbsNumber "\v<\d+>" contained containedin=hbsComponent,hbsMustache,hbsMustacheBlock,hbsPencil,hbsElseBlock
syntax match hbsBool "\v<(true|false)>" contained containedin=hbsComponent,hbsMustache,hbsMustacheBlock,hbsPencil,hbsElseBlock
syntax match hbsArg "\v(\@\S+|\S+)\=@=" contained containedin=hbsComponent,hbsMustache,hbsMustacheBlock,hbsPencil,hbsElseBlock
syntax match hbsOperator "\v(\S+)@<=\=" contained containedin=hbsComponent,hbsMustache,hbsMustacheBlock,hbsPencil,hbsElseBlock

syntax region hbsComment start="\v\{\{\!" end="\v\}\}" keepend
syntax region hbsComment start="\v\{\{\!\-\-" end="\v\-\-\}\}" keepend

" *Comment	any comment

" *Constant	any constant
"  String		a string constant: "this is a string"
"  Character	a character constant: 'c', '\n'
"  Number		a number constant: 234, 0xff
"  Boolean	a boolean constant: TRUE, false
"  Float		a floating point constant: 2.3e10

" *Identifier	any variable name
"  Function	function name (also: methods for classes)

" *Statement	any statement
"  Conditional	if, then, else, endif, switch, etc.
"  Repeat		for, do, while, etc.
"  Label		case, default, etc.
"  Operator	"sizeof", "+", "*", etc.
"  Keyword	any other keyword
"  Exception	try, catch, throw

" *PreProc	generic Preprocessor
"  Include	preprocessor #include
"  Define		preprocessor #define
"  Macro		same as Define
"  PreCondit	preprocessor #if, #else, #endif, etc.

" *Type		int, long, char, etc.
"  StorageClass	static, register, volatile, etc.
"  Structure	struct, union, enum, etc.
"  Typedef	A typedef

" *Special	any special symbol
"  SpecialChar	special character in a constant
"  Tag		you can use CTRL-] on this
"  Delimiter	character that needs attention
"  SpecialComment	special things inside a comment
"  Debug		debugging statements

" *Underlined	text that stands out, HTML links

" *Ignore		left blank, hidden  |hl-Ignore|

" *Error		any erroneous construct

" *Todo		anything that needs extra attention; mostly the
" 		keywords TODO FIXME and XXX

highlight link hbsBuiltInHelper Function
highlight link hbsBuiltInHelperInElse Function
highlight link hbsControlFlow Function
highlight link hbsKeyword Keyword
highlight link hbsOperator Operator
highlight link hbsDelimiter Delimiter
highlight link hbsMustacheName Statement
highlight link hbsPencilName Statement
highlight link hbsIdentifier Identifier
highlight link hbsString String
highlight link hbsNumber Special
highlight link hbsBool Boolean
highlight link hbsHandles Define
highlight link hbsComponentStatement Define
highlight link hbsUnescapedHandles Identifier
highlight link hbsUnescapedIdentifier Identifier
highlight link hbsComment Comment
highlight link hbsArg Type

let b:current_syntax = "handlebars"
