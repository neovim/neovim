" scdoc compiler for Vim
" Compiler: scdoc
" Maintainer: Gregory Anders <contact@gpanders.com>
" Last Updated: 2019-10-24
"               2024 Apr 05 by The Vim Project (removed :CompilerSet definition)
" Upstream: https://github.com/gpanders/vim-scdoc

if exists('current_compiler')
    finish
endif
let current_compiler = 'scdoc'

CompilerSet makeprg=scdoc\ <\ %\ 2>&1
CompilerSet errorformat=Error\ at\ %l:%c:\ %m,%-G%.%#
