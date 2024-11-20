" Vim compiler file
" Compiler:	Mypy (Python static checker)
" Maintainer:   @Konfekt
" Last Change:	2024 Nov 19

if exists("current_compiler") | finish | endif
let current_compiler = "mypy"

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=mypy
let &l:makeprg = 'mypy --show-column-numbers '
	    \ ..get(b:, 'mypy_makeprg_params', get(g:, 'mypy_makeprg_params', '--strict --ignore-missing-imports'))
exe 'CompilerSet makeprg='..escape(&l:makeprg, ' \|"')
CompilerSet errorformat=%f:%l:%c:\ %t%*[^:]:\ %m

let &cpo = s:cpo_save
unlet s:cpo_save
