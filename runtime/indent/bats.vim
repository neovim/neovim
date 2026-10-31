" Vim indent file
" Language:	Bats (Bash Automated Testing System)
" Maintainer:	Grant Hutchins <git@nertzy.com>
" Last Change:	2026 Oct 12

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif

" Bats test files are Bash scripts; the indenting is in sh.vim.
unlet! b:is_sh
unlet! b:is_kornshell
let b:is_bash = 1

runtime! indent/sh.vim

" vim: ts=8
