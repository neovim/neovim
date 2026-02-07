" Vim compiler file
" Compiler:     Pyright (Python Type Checker)
" Maintainer:   @konfekt
" Last Change:  2025 Dec 26

if exists("current_compiler") | finish | endif
let current_compiler = "pyright"

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=pyright
" CompilerSet makeprg=basedpyright
exe 'CompilerSet makeprg=' ..  escape(
        \ get(b:, 'pyright_makeprg', get(g:, 'pyright_makeprg', 'pyright')),
        \ ' \|"')
CompilerSet errorformat=
      \%E%f:%l:%c\ -\ error:\ %m,
      \%W%f:%l:%c\ -\ warning:\ %m,
      \%N%f:%l:%c\ -\ note:\ %m,
      \%C[ \t]\ %.%#,
      \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
