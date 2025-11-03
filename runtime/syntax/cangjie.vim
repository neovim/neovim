" Vim syntax file
" Language: Cangjie
" Maintainer: Wu Junkai <wu.junkai@qq.com>
" URL: https://github.com/WuJunkai2004/cangjie.vim
" Last Change: 2025 Oct 12
"
" The Cangjie programming language is a new-generation programming
" language oriented to full-scenario intelligence. It features
" native intelligence, being naturally suitable for all scenarios,
" high performance and strong security. It is mainly applied in
" scenarios such as native applications and service applications
" of HarmonyOS NEXT, providing developers with a good programming
" experience.
"
" For more information, see:
" - https://cangjie-lang.cn/
" - https://gitcode.com/Cangjie

" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

let s:save_cpo = &cpo
set cpo&vim

" 0. check the user's settings
" use let g:cangjie_<item>_color to enable/disable syntax highlighting
function! s:enabled(item) abort
	return get(g:, 'cangjie_' . a:item . '_color', 1)
endfunction

syn case match

" 1. comments
syn keyword cangjieTodo	TODO FIXME XXX NOTE BUG contained
syn match   cangjieComment /\v\/\/.*/			contains=cangjieTodo
syn region  cangjieComment start=/\/\*/ end=/\*\//	contains=cangjieTodo,@Spell

" 2. keywords
syn keyword cangjieDeclaration	abstract extend macro foreign
syn keyword cangjieDeclaration	interface open operator override private prop protected
syn keyword cangjieDeclaration	public redef static type
syn keyword cangjieStatement	as break case catch continue do else finally for in
syn keyword cangjieStatement	if in is match quote return spawn super synchronized
syn keyword cangjieStatement	throw try unsafe where while
syn keyword cangjieIdentlike	false init main this true
syn keyword cangjieVariable	const let var
syn keyword cangjieOption	Option Some None
syn keyword cangjieDeclaration	func struct class enum import package nextgroup=cangjieTypeName skipwhite
syn cluster cangjieKeywordCluster contains=
	\ cangjieDeclaration,
	\ cangjieStatement,
	\ cangjieIdentlike,
	\ cangjieVariable,
	\ cangjieOption

" 3. macro (e.g., @override)
syn match cangjieMacro /@\h\w*/

" 4. Type and Function Names
syn match cangjieTypeName /\h\w*/ contained

" 5. specail identifiers
syn region cangjieSpIdentifier start=/`/ end=/`/ oneline

" 6. types
syn keyword cangjieSpType	Any Nothing Range Unit Iterable
syn keyword cangjieArrayType	Array ArrayList VArray
syn keyword cangjieHashType	HashMap HashSet
syn keyword cangjieCommonType	Bool Byte Rune String
syn keyword cangjieFloatType	Float16 Float32 Float64
syn keyword cangjieIntType	Int8 Int16 Int32 Int64 IntNative
syn keyword cangjieUIntType	UInt8 UInt16 UInt32 UInt64 UIntNative
syn cluster cangjieTypeCluster contains=
	\ cangjieSpType,
	\ cangjieArrayType,
	\ cangjieHashType,
	\ cangjieCommonType,
	\ cangjieFloatType,
	\ cangjieIntType,
	\ cangjieUIntType

" 7. character and strings
syn cluster cangjieInterpolatedPart contains=
	\ @cangjieKeywordCluster,
	\ cangjieSpIdentifier,
	\ @cangjieTypeCluster,
	\ @cangjieNumberCluster,
	\ cangjieOperator
syn region  cangjieInterpolation contained keepend start=/\${/ end=/}/ contains=@cangjieInterpolatedPart
syn match cangjieEscape /\v\\u\{[0-9a-fA-F]{1,8}\}|\\./ contained
syn match cangjieRuneError /\v[rb]'([^'\\]|\\.)*'/
syn match cangjieRuneError /\v[rb]"([^"\\]|\\.)*"/
syn match cangjieRune /\vr'(\\u\{[0-9a-fA-F]{1,8}\}|\\.|[^'\\])'/ contains=cangjieEscape
syn match cangjieRune /\vr"(\\u\{[0-9a-fA-F]{1,8}\}|\\.|[^"\\])"/ contains=cangjieEscape
syn match cangjieRune /\vb'(\\u\{[0-9a-fA-F]{1,8}\}|\\.|[^'\\])'/ contains=cangjieEscape
syn region cangjieString start=/"/ skip=/\\\\\|\\"/ end=/"/ oneline contains=cangjieInterpolation,cangjieEscape
syn region cangjieString start=/'/ skip=/\\\\\|\\'/ end=/'/ oneline contains=cangjieInterpolation,cangjieEscape
syn region cangjieString start=/"""/ skip=/\\\\\|\\"/ end=/"""/ contains=cangjieInterpolation,cangjieEscape keepend
syn region cangjieString start=/'''/ skip=/\\\\\|\\'/ end=/'''/ contains=cangjieInterpolation,cangjieEscape keepend
syn region cangjieRawString start='\z(#*\)#"'  end='"#\z1'
syn region cangjieRawString start='\z(#*\)#\'' end='\'#\z1'

" 8. number
syn match cangjieHexFloatNumber	/\v\c<0x([0-9a-f_]+\.?|[0-9a-f_]*\.[0-9a-f_]+)[p][-+]?\d[0-9_]*>/
syn match cangjieFloatNumber	/\v\c<\d[0-9_]*\.\d[0-9_]*([ep][-+]?\d[0-9_]*)?(f(16|32|64))?>/
syn match cangjieFloatNumber	/\v\c<\d[0-9_]*\.([ep][-+]?\d[0-9_]*)?(f(16|32|64))?>/
syn match cangjieFloatNumber	/\v\c\.\d[0-9_]*([ep][-+]?\d[0-9_]*)?(f(16|32|64))?>/
syn match cangjieScienceNumber	/\v\c<\d[0-9_]*[e][-+]?\d[0-9_]*(f(16|32|64))?>/
syn match cangjieHexNumber	/\v\c<0x[0-9a-f_]+([iu](8|16|32|64))?>/
syn match cangjieOctalNumber	/\v\c<0o[0-7_]+([iu](8|16|32|64))?>/
syn match cangjieBinaryNumber	/\v\c<0b[01_]+([iu](8|16|32|64))?>/
syn match cangjieDecimalNumber	/\v\c<\d[0-9_]*([iu](8|16|32|64))?>/
syn cluster cangjieNumberCluster contains=
	\ cangjieHexFloatNumber,
	\ cangjieFloatNumber,
	\ cangjieScienceNumber,
	\ cangjieHexNumber,
	\ cangjieOctalNumber,
	\ cangjieBinaryNumber,
	\ cangjieDecimalNumber

" 9. operators
syn match cangjieOperator /[-+%<>!&|^*=]=\?/
syn match cangjieOperator /\/\%(=\|\ze[^/*]\)/
syn match cangjieOperator /\%(<<\|>>\|&^\)=\?/
syn match cangjieOperator /:=\|||\|<-\|++\|--/
syn match cangjieOperator /[~]/
syn match cangjieOperator /[:]/
syn match cangjieOperator /\.\./
syn match cangjieVarArgs  /\.\.\./

" 10. folding
syn region cangjieFoldBraces transparent fold start='{' end='}' contains=ALLBUT,cangjieComment
syn region cangjieFoldParens transparent fold start='(' end=')' contains=ALLBUT,cangjieComment
syn region cangjieFoldBrackets transparent fold start='\[' end='\]' contains=ALLBUT,cangjieComment

" finally, link the syntax groups to the highlight groups
if s:enabled('comment')
	hi def link cangjieTodo			Todo
	hi def link cangjieComment		Comment
endif
if s:enabled('identifier')
	hi def link cangjieSpIdentifier		Identifier
endif
if s:enabled('keyword')
	hi def link cangjieDeclaration		Keyword
	hi def link cangjieStatement		Statement
	hi def link cangjieIdentlike		Keyword
	hi def link cangjieVariable		Keyword
	hi def link cangjieOption		Keyword
endif
if s:enabled('macro')
	hi def link cangjieMacro		PreProc
endif
if s:enabled('number')
	hi def link cangjieHexFloatNumber	Number
	hi def link cangjieFloatNumber		Float
	hi def link cangjieScienceNumber	Float
	hi def link cangjieHexNumber		Number
	hi def link cangjieOctalNumber		Number
	hi def link cangjieBinaryNumber		Number
	hi def link cangjieDecimalNumber	Number
endif
if s:enabled('operator')
	hi def link cangjieOperator		Operator
	hi def link cangjieVarArgs		Operator
endif
if s:enabled('string')
	hi def link cangjieRune			Character
	hi def link cangjieRuneError		Error
	hi def link cangjieString		String
	hi def link cangjieRawString		String
	hi def link cangjieEscape		SpecialChar
endif
if s:enabled('type')
	hi def link cangjieTypeName		Type
	hi def link cangjieSpType		Type
	hi def link cangjieArrayType		Type
	hi def link cangjieHashType		Type
	hi def link cangjieCommonType		Type
	hi def link cangjieFloatType		Type
	hi def link cangjieIntType		Type
	hi def link cangjieUIntType		Type
endif

let b:current_syntax = "cangjie"

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: ts=8 sw=8 noet
