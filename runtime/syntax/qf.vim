" Vim syntax file
" Language:		Quickfix window
" Maintainer:		The Vim Project <https://github.com/vim/vim>
" Last Change:		2026 Jan 31
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn match	qfFileName	"^[^|]*"	   nextgroup=qfSeparator1
syn match	qfSeparator1	"|"	 contained nextgroup=qfLineNr
syn match	qfLineNr	"[^|]*"	 contained nextgroup=qfSeparator2 contains=@qfType
syn match	qfSeparator2	"|"	 contained nextgroup=qfText
syn match	qfText		".*"	 contained

syn match	qfError		"error"	  contained
syn match	qfWarning	"warning" contained
syn match	qfNote		"note"    contained
syn match	qfInfo		"info"    contained
syn cluster	qfType		contains=qfError,qfWarning,qfNote,qfInfo

" The default highlighting.
hi def link qfFileName		Directory
hi def link qfLineNr		LineNr
hi def link qfSeparator1	Delimiter
hi def link qfSeparator2	Delimiter
hi def link qfText		Normal
hi def link qfError		Error

let b:current_syntax = "qf"

" vim: ts=8
