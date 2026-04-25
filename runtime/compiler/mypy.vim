" Vim compiler file
" Compiler:	Mypy (Python static checker)
" Maintainer:   @Konfekt
" Last Change:	2025 Nov 06

if exists("current_compiler") | finish | endif
let current_compiler = "mypy"

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=mypy
exe 'CompilerSet makeprg=' .. escape('mypy --show-column-numbers '
      \ ..get(b:, 'mypy_makeprg_params', get(g:, 'mypy_makeprg_params', '--strict --ignore-missing-imports')),
      \ ' \|"')
CompilerSet errorformat=%f:%l:%c:\ %t%*[^:]:\ %m

let &cpo = s:cpo_save
unlet s:cpo_save
