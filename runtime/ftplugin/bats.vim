" Vim filetype plugin file
" Language:	Bats (Bash Automated Testing System)
" Maintainer:	Grant Hutchins <git@nertzy.com>
" Last Change:	2026 Oct 12
"
" Bats test files are Bash scripts with a few extensions, such as @test
" blocks.  Use the "sh" filetype plugin with b:is_bash set.

if exists("b:did_ftplugin")
  finish
endif

unlet! b:is_sh
unlet! b:is_kornshell
let b:is_bash = 1

runtime! ftplugin/sh.vim ftplugin/sh_*.vim ftplugin/sh/*.vim

" vim: ts=8
