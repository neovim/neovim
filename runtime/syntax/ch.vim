" Vim syntax file
" Language:     Ch
" Maintainer:   SoftIntegration, Inc. <info@softintegration.com>
" URL:		http://www.softintegration.com/download/vim/syntax/ch.vim
" Last change:	2004 Sep 01
"		Created based on cpp.vim
"
" Ch is a C/C++ interpreter with many high level extensions
"

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Read the C syntax to start with
if version < 600
  so <sfile>:p:h/c.vim
else
  runtime! syntax/c.vim
  unlet b:current_syntax
endif

" Ch extentions

syn keyword	chStatement	new delete this foreach
syn keyword	chAccess	public private
syn keyword	chStorageClass	__declspec(global) __declspec(local)
syn keyword	chStructure	class
syn keyword	chType		string_t array

" Default highlighting
if version >= 508 || !exists("did_ch_syntax_inits")
  if version < 508
    let did_ch_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif
  HiLink chAccess		chStatement
  HiLink chExceptions		Exception
  HiLink chStatement		Statement
  HiLink chType			Type
  HiLink chStructure		Structure
  delcommand HiLink
endif

let b:current_syntax = "ch"

" vim: ts=8
