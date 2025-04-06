" Vim compiler file
" Compiler:     Pylint for Python
" Maintainer:   Daniel Moch <daniel@danielmoch.com>
" Last Change:  2024 Nov 07 by The Vim Project (added params variable)
"		2024 Nov 19 by the Vim Project (properly escape makeprg setting)

if exists("current_compiler") | finish | endif
let current_compiler = "pylint"

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=ruff
let &l:makeprg = 'pylint ' .
      \ '--output-format=text --msg-template="{path}:{line}:{column}:{C}: [{symbol}] {msg}" --reports=no ' .
      \ get(b:, "pylint_makeprg_params", get(g:, "pylint_makeprg_params", '--jobs=0'))
exe 'CompilerSet makeprg='..escape(&l:makeprg, ' \|"')
CompilerSet errorformat=%A%f:%l:%c:%t:\ %m,%A%f:%l:\ %m,%A%f:(%l):\ %m,%-Z%p^%.%#,%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
