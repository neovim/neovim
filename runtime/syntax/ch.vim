" Vim syntax file
" Language:     Ch
" Maintainer:   SoftIntegration, Inc. <info@softintegration.com>
" URL:		http://www.softintegration.com/download/vim/syntax/ch.vim
" Last change:	2004 Sep 01
"		Created based on cpp.vim
"
" Ch is a C/C++ interpreter with many high level extensions
"

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the C syntax to start with
runtime! syntax/c.vim
unlet b:current_syntax

" Ch extentions

syn keyword	chStatement	new delete this foreach
syn keyword	chAccess	public private
syn keyword	chStorageClass	__declspec(global) __declspec(local)
syn keyword	chStructure	class
syn keyword	chType		string_t array

" Default highlighting

hi def link chAccess		chStatement
hi def link chExceptions		Exception
hi def link chStatement		Statement
hi def link chType			Type
hi def link chStructure		Structure

let b:current_syntax = "ch"

" vim: ts=8
