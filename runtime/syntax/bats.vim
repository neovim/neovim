" Vim syntax file
" Language:	Bats (Bash Automated Testing System)
" Maintainer:	Grant Hutchins <git@nertzy.com>
" Last Change:	2026 Oct 14

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Bats test files are Bash scripts; the syntax is in sh.vim.
unlet! b:is_sh
unlet! b:is_kornshell
let b:is_bash = 1

runtime! syntax/sh.vim
unlet! b:current_syntax

" @test name { ... }: the body is a function body, folded like one when
" g:sh_fold_enabled asks for function folding.  As in bats-preprocess, the
" name runs up to the last blank-preceded "{" on the line.
syn match batsTest	"^\s*\zs@test\ze\s"	skipwhite nextgroup=batsTestName
syn match batsTestName	contained	"\S\%(.*\S\)\=\ze\s\+{"	contains=shDoubleQuote,shSingleQuote,shDeref,shDerefSimple skipwhite nextgroup=shFunctionExpr

" # bats test_tags=... and # bats file_tags=...
syn match batsTagComment	"^\s*\zs#\s*bats\s\+\%(test\|file\)_tags=.*$"

" Commands provided by bats-core
syn cluster shCommandSubList add=batsStatement
syn cluster shCaseList add=batsStatement
syn keyword batsStatement run skip load bats_load_safe bats_load_library bats_load_library_safe bats_require_minimum_version bats_pipe bats_test_function

hi def link batsTest		Keyword
hi def link batsTestName	String
hi def link batsTagComment	SpecialComment
hi def link batsStatement	shStatement

let b:current_syntax = 'bats'

" vim: ts=8
