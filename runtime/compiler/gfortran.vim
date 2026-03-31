" Compiler: GNU Fortran Compiler
" Maintainer: H Xu <xuhdev@gmail.com>
" Version: 0.1.3
" Last Change: 2012 Apr 30
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)
" Homepage: http://www.vim.org/scripts/script.php?script_id=3496
"           https://bitbucket.org/xuhdev/compiler-gfortran.vim
" License: Same as Vim

if exists('current_compiler')
    finish
endif
let current_compiler = 'gfortran'
let s:keepcpo= &cpo
set cpo&vim

CompilerSet errorformat=
            \%A%f:%l.%c:,
            \%-Z%trror:\ %m,
            \%-Z%tarning:\ %m,
            \%-C%.%#

let &cpo = s:keepcpo
unlet s:keepcpo
