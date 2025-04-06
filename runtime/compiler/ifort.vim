" Compiler: Intel Fortran Compiler
" Maintainer: H Xu <xuhdev@gmail.com>
" Version: 0.1.1
" Last Change: 2012 Apr 30
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)
" Homepage: http://www.vim.org/scripts/script.php?script_id=3497
"           https://bitbucket.org/xuhdev/compiler-ifort.vim
" License: Same as Vim

if exists('current_compiler')
    finish
endif
let current_compiler = 'ifort'
let s:keepcpo= &cpo
set cpo&vim

CompilerSet errorformat=
            \%A%f(%l):\ %trror\ \#%n:\ %m,
            \%A%f(%l):\ %tarning\ \#%n:\ %m,
            \%-Z%p^,
            \%-G%.%#

let &cpo = s:keepcpo
unlet s:keepcpo
