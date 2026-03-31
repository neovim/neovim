" Vim compiler file
" Compiler:     Ty (Python Type Checker)
" Maintainer:   @konfekt
" Last Change:  2024 Dec 24

if exists("current_compiler") | finish | endif
let current_compiler = "ty"

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=ty
exe 'CompilerSet makeprg=' ..  escape(
        \ get(b:, 'ty_makeprg', get(g:, 'ty_makeprg', 'ty check --no-progress --color=never'))
        \ ..' --output-format=concise', ' \|"')
CompilerSet errorformat=%f:%l:%c:\ %m,%f:%l:\ %m,%f:%l:%c\ -\ %m,%f:
CompilerSet errorformat+=%-GFound\ %.%#

let &cpo = s:cpo_save
unlet s:cpo_save
