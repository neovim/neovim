" Vim compiler file
" Compiler:     Ruff (Python linter)
" Maintainer:   @pbnj-dragon
" Last Change:  2024 Nov 07

if exists("current_compiler") | finish | endif
let current_compiler = "ruff"

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=ruff
let &l:makeprg= 'ruff check --output-format=concise '
        \ ..get(b:, 'ruff_makeprg_params', get(g:, 'ruff_makeprg_params', '--preview'))
exe 'CompilerSet makeprg='..escape(&l:makeprg, ' "')
CompilerSet errorformat=%f:%l:%c:\ %m,%f:%l:\ %m,%f:%l:%c\ -\ %m,%f:

let &cpo = s:cpo_save
unlet s:cpo_save
