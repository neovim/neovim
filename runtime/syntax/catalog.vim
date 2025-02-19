" Vim syntax file
" Language:	sgml catalog file
" Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:	Fr, 04 Nov 2005 12:46:45 CET
" Filenames:	/etc/sgml.catalog
" $Id: catalog.vim,v 1.2 2005/11/23 21:11:10 vimboss Exp $

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

" strings
syn region  catalogString start=+"+ skip=+\\\\\|\\"+ end=+"+ keepend
syn region  catalogString start=+'+ skip=+\\\\\|\\'+ end=+'+ keepend

syn region  catalogComment      start=+--+   end=+--+ contains=catalogTodo
syn keyword catalogTodo		TODO FIXME XXX NOTE contained
syn keyword catalogKeyword	DOCTYPE OVERRIDE PUBLIC DTDDECL ENTITY CATALOG


" The default highlighting.
hi def link catalogString		     String
hi def link catalogComment		     Comment
hi def link catalogTodo			     Todo
hi def link catalogKeyword		     Statement

let b:current_syntax = "catalog"
