" Vim syntax file
" Language: squirrel
" Current Maintainer: Matt Dunford (zenmatic@gmail.com)
" URL: https://github.com/zenmatic/vim-syntax-squirrel
" Last Change:	2021 Nov 28

" http://squirrel-lang.org/

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" inform C syntax that the file was included from cpp.vim
let b:filetype_in_cpp_family = 1

" Read the C syntax to start with
runtime! syntax/c.vim
unlet b:current_syntax

" squirrel extensions
syn keyword squirrelStatement	delete this in yield resume base clone
syn keyword squirrelAccess	local
syn keyword cConstant           null
syn keyword squirrelModifier	static
syn keyword squirrelType	bool instanceof typeof
syn keyword squirrelExceptions	throw try catch
syn keyword squirrelStructure	class function extends constructor
syn keyword squirrelBoolean	true false
syn keyword squirrelRepeat	foreach

syn region squirrelMultiString start='@"' end='"$' end='";$'me=e-1

syn match squirrelShComment "^\s*#.*$"

" Default highlighting
hi def link squirrelAccess		squirrelStatement
hi def link squirrelExceptions		Exception
hi def link squirrelStatement		Statement
hi def link squirrelModifier		Type
hi def link squirrelType		Type
hi def link squirrelStructure		Structure
hi def link squirrelBoolean		Boolean
hi def link squirrelMultiString		String
hi def link squirrelRepeat		cRepeat
hi def link squirrelShComment		Comment

let b:current_syntax = "squirrel"

" vim: ts=8
