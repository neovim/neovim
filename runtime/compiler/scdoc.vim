" scdoc compiler for Vim
" Compiler: scdoc
" Maintainer: Greg Anders <greg@gpanders.com>
" Last Updated: 2019-10-24

if exists('current_compiler')
    finish
endif
let current_compiler = 'scdoc'

if exists(':CompilerSet') != 2
    command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=scdoc\ <\ %\ 2>&1
CompilerSet errorformat=Error\ at\ %l:%c:\ %m,%-G%.%#
