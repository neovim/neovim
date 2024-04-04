" Compiler: G95
" Maintainer: H Xu <xuhdev@gmail.com>
" Version: 0.1.3
" Last Change: 2012 Apr 30
"              2024 Apr 03 by The Vim Project (removed :CompilerSet definition)
" Homepage: http://www.vim.org/scripts/script.php?script_id=3492
"           https://bitbucket.org/xuhdev/compiler-g95.vim
" License: Same as Vim

if exists('current_compiler')
    finish
endif
let current_compiler = 'g95'
let s:keepcpo= &cpo
set cpo&vim

CompilerSet errorformat=
            \%AIn\ file\ %f:%l,
            \%-C%p1,
            \%-Z%trror:\ %m,
            \%-Z%tarning\ (%n):\ %m,
            \%-C%.%#

let &cpo = s:keepcpo
unlet s:keepcpo
