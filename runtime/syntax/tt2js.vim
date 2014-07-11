" Language:      TT2 embedded with Javascript
" Maintainer:    Andy Lester <andy@petdance.com>
" Author:        Yates, Peter <pd.yates@gmail.com>
" Homepage:      http://github.com/vim-perl/vim-perl
" Bugs/requests: http://github.com/vim-perl/vim-perl/issues
" Last Change:   2013-07-21

if exists("b:current_syntax")
    finish
endif

runtime! syntax/javascript.vim
unlet b:current_syntax

runtime! syntax/tt2.vim
unlet b:current_syntax

syn cluster javascriptPreProc add=@tt2_top_cluster

let b:current_syntax = "tt2js"
