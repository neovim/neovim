" Vim compiler file
" Compiler:     Ruff (Python linter)
" Maintainer:   @pbnj-dragon
" Last Change:  2024 Nov 07
"		2024 Nov 19 by the Vim Project (properly escape makeprg setting)
"		2025 Nov 06 by the Vim Project (do not set buffer-local makeprg)

if exists("current_compiler") | finish | endif
let current_compiler = "ruff"

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=ruff
exe 'CompilerSet makeprg=' .. escape('ruff check --output-format=concise '
        \ ..get(b:, 'ruff_makeprg_params', get(g:, 'ruff_makeprg_params', '--preview')),
        \ ' \|"')
CompilerSet errorformat=%f:%l:%c:\ %m,%f:%l:\ %m,%f:%l:%c\ -\ %m,%f:

let &cpo = s:cpo_save
unlet s:cpo_save
