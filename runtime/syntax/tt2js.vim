" Vim syntax file
" Language:      TT2 embedded with Javascript
" Maintainer:    Andy Lester <andy@petdance.com>
" Author:        Yates, Peter <pd.yates@gmail.com>
" Homepage:      https://github.com/vim-perl/vim-perl
" Bugs/requests: https://github.com/vim-perl/vim-perl/issues
" License:       Vim License (see :help license)
" Last Change:   2018 Mar 28

if exists("b:current_syntax")
    finish
endif

runtime! syntax/javascript.vim
unlet b:current_syntax

runtime! syntax/tt2.vim
unlet b:current_syntax

syn cluster javascriptPreProc add=@tt2_top_cluster

let b:current_syntax = "tt2js"
